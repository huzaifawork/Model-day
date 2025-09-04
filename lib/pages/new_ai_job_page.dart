import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/models/ai_job.dart';
import 'package:new_flutter/services/ai_jobs_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:intl/intl.dart';

class NewAiJobPage extends StatefulWidget {
  const NewAiJobPage({super.key});

  @override
  State<NewAiJobPage> createState() => _NewAiJobPageState();
}

class _NewAiJobPageState extends State<NewAiJobPage> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedAgentId;

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  // Field navigation

  // Manual focus nodes for better control
  late List<FocusNode> _manualFocusNodes;

  String _selectedType = 'text_to_image';
  String _selectedStatus = 'pending';
  String _selectedPaymentStatus = 'unpaid';
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingId;

  final List<String> _aiJobTypes = [
    'text_to_image',
    'image_to_image',
    'video_generation',
    'voice_cloning',
    'avatar_creation',
    'virtual_modeling',
    'ai_photography',
    'deepfake_modeling'
  ];

  final List<String> _statusOptions = [
    'pending',
    'in_progress',
    'completed',
    'canceled'
  ];

  final List<String> _paymentStatusOptions = [
    'unpaid',
    'paid',
    'partial',
    'pending'
  ];

  final List<String> _currencies = [
    'USD',
    'EUR',
    'GBP',
    'PLN',
    'ILS',
    'JPY',
    'KRW',
    'CNY',
    'AUD'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize manual focus nodes for text fields (5 text fields)
    _manualFocusNodes = List.generate(5, (index) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null) {
        if (args is Map<String, dynamic>) {
          _loadInitialData(args);
        } else if (args is String) {
          _loadAiJob(args);
        } else if (args is AiJob) {
          // Handle AiJob object directly
          _loadAiJobFromObject(args);
        }
      }
    });
  }

  void _loadInitialData(Map<String, dynamic> data) {
    setState(() {
      _clientNameController.text = data['clientName'] ?? '';
      _selectedDate = DateTime.tryParse(data['date'] ?? '') ?? DateTime.now();
      if (data['startTime'] != null && data['startTime'].isNotEmpty) {
        final timeParts = data['startTime'].split(':');
        _startTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
      if (data['endTime'] != null && data['endTime'].isNotEmpty) {
        final timeParts = data['endTime'].split(':');
        _endTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
      _locationController.text = data['location'] ?? '';
      _rateController.text = data['rate'] ?? '';
      _selectedCurrency = data['currency'] ?? 'USD';
      _notesController.text = data['notes'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _selectedAgentId = data['bookingAgent'];
      if (data['type'] != null && _aiJobTypes.contains(data['type'])) {
        _selectedType = data['type'];
      }
    });
  }

  void _loadAiJobFromObject(AiJob aiJob) {
    setState(() {
      _isEditing = true;
      _editingId = aiJob.id;
      _clientNameController.text = aiJob.clientName;
      _selectedType = aiJob.type ?? 'text_to_image';
      _descriptionController.text = aiJob.description ?? '';
      _locationController.text = aiJob.location ?? '';
      _selectedAgentId = aiJob.bookingAgent;
      _selectedDate = aiJob.date ?? DateTime.now();
      _rateController.text = aiJob.rate?.toString() ?? '';
      _notesController.text = aiJob.notes ?? '';
      _selectedStatus = aiJob.status ?? 'pending';
      _selectedPaymentStatus = aiJob.paymentStatus ?? 'unpaid';
      _selectedCurrency = aiJob.currency ?? 'USD';

      // Parse time string
      if (aiJob.time != null && aiJob.time!.isNotEmpty) {
        final timeParts = aiJob.time!.split(':');
        _startTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
    });
  }

  Future<void> _loadAiJob(String id) async {
    setState(() {
      _isLoading = true;
      _isEditing = true;
      _editingId = id;
    });

    try {
      final aiJob = await AiJobsService.getById(id);
      if (aiJob != null) {
        _loadAiJobFromObject(aiJob);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading AI job: $e'),
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
    _clientNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    _formNavigation.dispose();

    // Dispose manual focus nodes
    for (final focusNode in _manualFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  Future<void> _handleOcrDataExtracted(Map<String, dynamic> data) async {
    debugPrint('🤖 OCR data extracted for AI job: $data');

    setState(() {
      // Set default date to current date if no date extracted
      if (data['date'] != null) {
        try {
          _selectedDate = DateTime.parse(data['date']);
        } catch (e) {
          debugPrint('Could not parse date: ${data['date']}');
          _selectedDate = DateTime.now();
        }
      }

      // Map client name
      if (data['clientName'] != null) {
        _clientNameController.text = data['clientName'];
      }

      // Map AI job type
      if (data['aiJobType'] != null || data['type'] != null) {
        final typeStr =
            (data['aiJobType'] ?? data['type']).toString().toLowerCase();
        // Map common AI job type variations
        if (typeStr.contains('text') && typeStr.contains('image')) {
          _selectedType = 'text_to_image';
        } else if (typeStr.contains('image') && typeStr.contains('image')) {
          _selectedType = 'image_to_image';
        } else if (typeStr.contains('video')) {
          _selectedType = 'video_generation';
        } else if (typeStr.contains('voice') || typeStr.contains('audio')) {
          _selectedType = 'voice_cloning';
        } else if (typeStr.contains('avatar')) {
          _selectedType = 'avatar_creation';
        } else if (typeStr.contains('virtual') ||
            typeStr.contains('modeling')) {
          _selectedType = 'virtual_modeling';
        } else if (typeStr.contains('photography')) {
          _selectedType = 'ai_photography';
        } else if (typeStr.contains('deepfake')) {
          _selectedType = 'deepfake_modeling';
        } else if (_aiJobTypes.contains(typeStr)) {
          _selectedType = typeStr;
        }
      }

      // Map description
      if (data['description'] != null) {
        _descriptionController.text = data['description'];
      }

      // Map location
      if (data['location'] != null) {
        _locationController.text = data['location'];
      }

      // Map start time
      if (data['time'] != null || data['startTime'] != null) {
        final timeStr = (data['startTime'] ?? data['time']).toString();
        try {
          if (timeStr.contains('AM') || timeStr.contains('PM')) {
            // 12-hour format parsing
            final cleanTime =
                timeStr.replaceAll(RegExp(r'[^\d:APM\s]'), '').trim();
            final timePart = cleanTime.split(' ')[0];
            final parts = timePart.split(':');
            if (parts.length >= 2) {
              int hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              if (timeStr.toUpperCase().contains('PM') && hour != 12) {
                hour += 12;
              }
              if (timeStr.toUpperCase().contains('AM') && hour == 12) {
                hour = 0;
              }
              _startTime = TimeOfDay(hour: hour, minute: minute);
            }
          } else {
            // 24-hour format parsing
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              _startTime = TimeOfDay(hour: hour, minute: minute);
            }
          }
        } catch (e) {
          debugPrint('Could not parse start time: $timeStr');
        }
      }

      // Map rate and currency
      if (data['rate'] != null || data['dayRate'] != null) {
        final rateValue = data['rate'] ?? data['dayRate'];
        _rateController.text = rateValue.toString();
      }

      if (data['currency'] != null) {
        final currency = data['currency'].toString().toUpperCase();
        if (_currencies.contains(currency)) {
          _selectedCurrency = currency;
        }
      }

      // Map status
      if (data['status'] != null) {
        final status = data['status'].toString().toLowerCase();
        if (status.contains('progress') || status.contains('working')) {
          _selectedStatus = 'in_progress';
        } else if (status.contains('complet')) {
          _selectedStatus = 'completed';
        } else if (status.contains('cancel')) {
          _selectedStatus = 'canceled';
        } else if (_statusOptions.contains(status)) {
          _selectedStatus = status;
        }
      }

      // Map payment status
      if (data['paymentStatus'] != null) {
        final paymentStatus = data['paymentStatus'].toString().toLowerCase();
        if (_paymentStatusOptions.contains(paymentStatus)) {
          _selectedPaymentStatus = paymentStatus;
        }
      }

      // Agent matching moved outside setState - see below
      if (data['bookingAgent'] != null) {
        debugPrint('✅ Agent will be set after setState');
      } else {
        debugPrint('❌ No agent found in OCR data');
      }

      // Map requirements/specifications to notes
      if (data['requirements'] != null) {
        final currentNotes = _notesController.text;
        final requirements = 'Requirements: ${data['requirements']}';
        _notesController.text = currentNotes.isEmpty
            ? requirements
            : '$currentNotes\n$requirements';
      }

      if (data['specifications'] != null) {
        final currentNotes = _notesController.text;
        final specs = 'Specifications: ${data['specifications']}';
        _notesController.text =
            currentNotes.isEmpty ? specs : '$currentNotes\n$specs';
      }

      // Add description/notes from OCR if available
      if (data['notes'] != null) {
        final currentNotes = _notesController.text;
        final ocrNotes = data['notes'].toString();
        _notesController.text =
            currentNotes.isEmpty ? ocrNotes : '$currentNotes\n$ocrNotes';
      }

      // Add contact information if available
      if (data['email'] != null || data['phone'] != null) {
        final currentNotes = _notesController.text;
        final contactInfo = <String>[];
        if (data['email'] != null) contactInfo.add('Email: ${data['email']}');
        if (data['phone'] != null) contactInfo.add('Phone: ${data['phone']}');
        final contact = contactInfo.join('\n');
        _notesController.text =
            currentNotes.isEmpty ? contact : '$currentNotes\n$contact';
      }
    });

    debugPrint('🤖 AI job form populated with OCR data');

    // Add ALL extracted data to notes for complete record
    _appendAllExtractedDataToNotes(data);

    // Handle agent matching after setState (async operation)
    if (data['bookingAgent'] != null) {
      debugPrint('🔍 Now matching agent: ${data['bookingAgent']}');
      await _matchAgentIntelligently(data['bookingAgent'].toString());
    }
  }

  /// Intelligently match extracted agent name against actual agents in the system
  Future<void> _matchAgentIntelligently(String extractedAgentName) async {
    try {
      debugPrint('🔍 Matching agent: "$extractedAgentName"');

      // Load all available agents
      final agentsService = AgentsService();
      final agents = await agentsService.getAgents();

      debugPrint(
          '📋 Available agents: ${agents.map((a) => '${a.name} (${a.id})').toList()}');

      if (agents.isEmpty) {
        debugPrint('❌ No agents found in system');
        return;
      }

      final extractedLower = extractedAgentName.toLowerCase().trim();

      // Try exact match first
      for (final agent in agents) {
        if (agent.name.toLowerCase() == extractedLower) {
          debugPrint('✅ Exact match found: ${agent.name} (${agent.id})');
          setState(() {
            _selectedAgentId = agent.id;
          });
          return;
        }
      }

      // Try partial match (contains)
      for (final agent in agents) {
        final agentNameLower = agent.name.toLowerCase();
        if (agentNameLower.contains(extractedLower) ||
            extractedLower.contains(agentNameLower)) {
          debugPrint('✅ Partial match found: ${agent.name} (${agent.id})');
          setState(() {
            _selectedAgentId = agent.id;
          });
          return;
        }
      }

      // Try fuzzy matching (split names and check parts)
      final extractedParts = extractedLower.split(' ');
      for (final agent in agents) {
        final agentParts = agent.name.toLowerCase().split(' ');
        bool hasMatch = false;

        for (final extractedPart in extractedParts) {
          for (final agentPart in agentParts) {
            if (extractedPart.length > 2 && agentPart.contains(extractedPart)) {
              hasMatch = true;
              break;
            }
          }
          if (hasMatch) break;
        }

        if (hasMatch) {
          debugPrint('✅ Fuzzy match found: ${agent.name} (${agent.id})');
          setState(() {
            _selectedAgentId = agent.id;
          });
          return;
        }
      }

      // No match found - use first agent as default
      if (agents.isNotEmpty) {
        debugPrint(
            '⚠️ No match for "$extractedAgentName", using first agent: ${agents.first.name}');
        setState(() {
          _selectedAgentId = agents.first.id;
        });
      }
    } catch (e) {
      debugPrint('❌ Error matching agent: $e');
    }
  }

  /// Append ALL extracted OCR data to notes field for complete record
  void _appendAllExtractedDataToNotes(Map<String, dynamic> extractedData) {
    final List<String> allData = [];

    // Add header
    

    // Add all non-null extracted data
    extractedData.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        // Format the key to be more readable
        final formattedKey = _formatFieldName(key);
        allData.add('$formattedKey: $value');
      }
    });

    // Add timestamp
    allData.add('Extracted: ${DateTime.now().toString().substring(0, 19)}');
    

    // Append to existing notes
    final currentNotes = _notesController.text.trim();
    final ocrData = allData.join('\n');

    if (currentNotes.isEmpty) {
      _notesController.text = ocrData;
    } else {
      _notesController.text = '$currentNotes\n\n$ocrData';
    }

    debugPrint('📝 Added ${extractedData.length} OCR fields to notes');
  }

  /// Format field names to be more readable
  String _formatFieldName(String fieldName) {
    // Convert camelCase to readable format
    final formatted = fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .toLowerCase()
        .split(' ')
        .map((word) =>
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return formatted;
  }




  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.goldColor,
              surface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.goldColor,
              surface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint('🤖 NewAiJobPage._handleSubmit() - Starting submit...');
    setState(() {
      _isLoading = true;
    });

    try {
      final aiJob = AiJob(
        id: _editingId,
        clientName: _clientNameController.text,
        type: _selectedType,
        description: _descriptionController.text,
        location: _locationController.text,
        bookingAgent: _selectedAgentId,
        date: _selectedDate,
        time: _formatTime(_startTime),
        rate: double.tryParse(_rateController.text),
        currency: _selectedCurrency,
        notes: _notesController.text,
        status: _selectedStatus,
        paymentStatus: _selectedPaymentStatus,
      );

      debugPrint(
          '🤖 NewAiJobPage._handleSubmit() - AI job data: ${aiJob.toJson()}');

      if (_isEditing && _editingId != null) {
        debugPrint(
            '🤖 NewAiJobPage._handleSubmit() - Updating AI job with ID: $_editingId');
        await AiJobsService.update(_editingId!, aiJob.toJson());
      } else {
        debugPrint('🤖 NewAiJobPage._handleSubmit() - Creating new AI job');
        await AiJobsService.create(aiJob.toJson());
      }

      debugPrint('🤖 NewAiJobPage._handleSubmit() - AI job saved successfully');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ NewAiJobPage._handleSubmit() - Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving AI job: $e'),
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
        currentPage: '/new-ai-job',
        title: _isEditing ? 'Edit AI Job' : 'New AI Job',
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AppLayout(
      currentPage: '/new-ai-job',
      title: _isEditing ? 'Edit AI Job' : 'New AI Job',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new AI jobs (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  // Auto-submit disabled for testing
                  // onAutoSubmit: () {
                  //   debugPrint('Auto-submitting AI job form after OCR...');
                  //   _handleSubmit();
                  // },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information
              _buildSectionCard(
                'Basic Information',
                [
                  TextFormField(
                    controller: _clientNameController,
                    focusNode: _manualFocusNodes[0], // Client Name
                    decoration: const InputDecoration(
                      labelText: 'Client Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter client name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildAiJobTypeField(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    focusNode: _manualFocusNodes[1], // Description
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    focusNode: _manualFocusNodes[2], // Location
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Scheduling
              _buildSectionCard(
                'Scheduling',
                [
                  _buildDateField(),
                  const SizedBox(height: 16),
                  _buildTimeField(),
                  const SizedBox(height: 16),
                  _buildStatusField(),
                ],
              ),
              const SizedBox(height: 24),

              // Payment Information
              _buildSectionCard(
                'Payment Information',
                [
                  _buildRateField(),
                  const SizedBox(height: 16),
                  _buildPaymentStatusField(),
                ],
              ),
              const SizedBox(height: 24),

              // Agent Information
              _buildSectionCard(
                'Agent Information',
                [
                  AgentDropdown(
                    selectedAgentId: _selectedAgentId,
                    labelText: 'Booking Agent',
                    hintText: 'Select an agent',
                    onChanged: (value) {
                      setState(() {
                        _selectedAgentId = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes
              _buildSectionCard(
                'Notes',
                [
                  TextFormField(
                    controller: _notesController,
                    focusNode: _manualFocusNodes[4], // Notes
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
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
                          : (_isEditing ? 'Update AI Job' : 'Create AI Job'),
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

  Widget _buildAiJobTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Job Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2E2E2E)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _aiJobTypes.contains(_selectedType) ? _selectedType : null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
            items: _aiJobTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value ?? 'text_to_image';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2E2E2E)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy-MM-dd').format(_selectedDate),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start Time',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTime(true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2E2E2E)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  _startTime != null ? _formatTime(_startTime) : 'Select time',
                  style: TextStyle(
                    color: _startTime != null ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2E2E2E)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _statusOptions.contains(_selectedStatus)
                ? _selectedStatus
                : _statusOptions.first,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
            items: _statusOptions.map((status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value ?? 'pending';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRateField() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _rateController,
            focusNode: _manualFocusNodes[3], // Rate
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Rate',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Currency',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2E2E2E)),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _currencies.contains(_selectedCurrency)
                      ? _selectedCurrency
                      : _currencies.first,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  items: _currencies.map((currency) {
                    return DropdownMenuItem<String>(
                      value: currency,
                      child: Text(
                        currency,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrency = value ?? 'USD';
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2E2E2E)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _paymentStatusOptions.contains(_selectedPaymentStatus)
                ? _selectedPaymentStatus
                : null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
            items: _paymentStatusOptions.map((status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPaymentStatus = value ?? 'unpaid';
              });
            },
          ),
        ),
      ],
    );
  }
}
