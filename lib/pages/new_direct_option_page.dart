import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/models/event.dart';
import 'package:new_flutter/providers/agents_provider.dart';

import 'package:new_flutter/services/direct_options_service.dart';
import 'package:new_flutter/services/file_upload_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewDirectOptionPage extends StatefulWidget {
  const NewDirectOptionPage({super.key});

  @override
  State<NewDirectOptionPage> createState() => _NewDirectOptionPageState();
}

class _NewDirectOptionPageState extends State<NewDirectOptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _dayRateController = TextEditingController();
  final _usageRateController = TextEditingController();
  final _notesController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _agencyFeeController = TextEditingController();
  final _transferToDirectBookingController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  // Field navigation

  // Manual focus nodes for better control
  late List<FocusNode> _manualFocusNodes;

  String _selectedOptionType = '';
  OptionStatus _selectedOptionStatus = OptionStatus.pending;
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime.now();
  DateTime? _endDate;
  String? _selectedAgentId = 'ogbhai(uzibhaikiagencykoishak)';
  bool _isCustomType = false;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isDateRange = false;
  String? _editingId;
  final List<PlatformFile> _selectedFiles = [];

  final List<String> _optionTypes = [
    'Add manually',
    'Commercial',
    'Editorial',
    'Fashion Show',
    'Lookbook',
    'On Stay',
    'Print',
    'Runway',
    'Social Media',
    'Web Content',
    'Other'
  ];

  // Status options are now handled by OptionStatus enum

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

    // Initialize manual focus nodes for text fields (5 text fields: Client Name, Custom Option Type, Location, Day Rate, Usage Rate, Notes)
    _manualFocusNodes = List.generate(6, (index) => FocusNode());
    debugPrint('🔧 NewDirectOptionPage.initState() - _isEditing: $_isEditing');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load agents data
      _loadAgentsData();

      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint('🔧 NewDirectOptionPage.initState() - args: $args');
      if (args != null) {
        if (args is Map<String, dynamic>) {
          debugPrint('🔧 Loading initial data from Map');
          _loadInitialData(args);
        } else if (args is String) {
          debugPrint('🔧 Loading direct option for editing: $args');
          _loadDirectOption(args);
        }
      } else {
        debugPrint('🔧 No arguments - new direct option mode');
      }
      debugPrint('🔧 Final _isEditing state: $_isEditing');
    });
  }

  void _loadInitialData(Map<String, dynamic> data) {
    setState(() {
      _clientNameController.text = data['clientName'] ?? '';
      _selectedDate = DateTime.tryParse(data['date'] ?? '') ?? DateTime.now();
      _locationController.text = data['location'] ?? '';
      _dayRateController.text = data['dayRate'] ?? '';
      _usageRateController.text = data['usageRate'] ?? '';
      _selectedCurrency = data['currency'] ?? 'USD';
      _notesController.text = data['notes'] ?? '';
      _selectedAgentId = data['bookingAgent'];

      // Load date range data
      _isDateRange = data['is_multi_day'] ?? false;
      if (data['end_date'] != null && data['end_date'].isNotEmpty) {
        _endDate = DateTime.tryParse(data['end_date']);
      }

      if (data['jobType'] != null && data['jobType'].isNotEmpty) {
        if (_optionTypes.contains(data['jobType'])) {
          _selectedOptionType = data['jobType'];
        } else {
          _selectedOptionType = 'Add manually';
          _isCustomType = true;
          _customTypeController.text = data['jobType'];
        }
      }
    });
  }

  void _loadAgentsData() {
    try {
      debugPrint('🔧 Loading agents data...');
      final agentsProvider = context.read<AgentsProvider>();
      agentsProvider.loadAgents();
    } catch (e) {
      debugPrint('❌ Error loading agents data: $e');
    }
  }

  Future<void> _handleOcrDataExtracted(
      Map<String, dynamic> extractedData) async {
    debugPrint('=== FORM HANDLER CALLED ===');
    debugPrint('OCR Data received: $extractedData');
    debugPrint('Keys received: ${extractedData.keys.toList()}');
    setState(() {
      // Populate form fields with extracted data
      if (extractedData['clientName'] != null) {
        debugPrint('Setting client name: ${extractedData['clientName']}');
        _clientNameController.text = extractedData['clientName'];
      } else {
        debugPrint('No clientName found in extracted data');
      }
      if (extractedData['location'] != null) {
        debugPrint('Setting location: ${extractedData['location']}');
        _locationController.text = extractedData['location'];
      } else {
        debugPrint('No location found in extracted data');
      }
      if (extractedData['notes'] != null) {
        debugPrint('Setting notes: ${extractedData['notes']}');
        _notesController.text = extractedData['notes'];
      } else {
        debugPrint('No notes found in extracted data');
      }
      if (extractedData['date'] != null) {
        debugPrint('Setting date: ${extractedData['date']}');
        try {
          _selectedDate = DateTime.parse(extractedData['date']);
          debugPrint('Date parsed successfully: $_selectedDate');
        } catch (e) {
          debugPrint('Error parsing date: $e');
          // If date parsing fails, keep the current date (DateTime.now())
          debugPrint('Keeping current date: $_selectedDate');
        }
      } else {
        debugPrint('No date found in extracted data');
      }
      if (extractedData['dayRate'] != null) {
        debugPrint('Setting day rate: ${extractedData['dayRate']}');
        _dayRateController.text = extractedData['dayRate'].toString();
      } else {
        debugPrint('No dayRate found in extracted data');
      }
      if (extractedData['usageRate'] != null) {
        debugPrint('Setting usage rate: ${extractedData['usageRate']}');
        _usageRateController.text = extractedData['usageRate'].toString();
      } else {
        debugPrint('No usageRate found in extracted data');
      }
      // Agent matching moved outside setState - see below
      if (extractedData['bookingAgent'] != null) {
        debugPrint('✅ Agent will be set after setState');
      } else {
        debugPrint('❌ No bookingAgent found in OCR data');
      }
      if (extractedData['time'] != null) {
        // Add time to notes if not already there
        final currentNotes = _notesController.text;
        if (!currentNotes.contains(extractedData['time'])) {
          _notesController.text = currentNotes.isEmpty
              ? 'Time: ${extractedData['time']}\n$currentNotes'
              : '$currentNotes\nTime: ${extractedData['time']}';
        }
      }

      // Handle Direct Options specific fields
      if (extractedData['optionType'] != null) {
        debugPrint(
            'Setting option type from extracted data: ${extractedData['optionType']}');
        final optionType = extractedData['optionType'].toString();
        if (_optionTypes.contains(optionType)) {
          _selectedOptionType = optionType;
          _isCustomType = false;
          debugPrint('Option type set to: $optionType');
        } else {
          _selectedOptionType = 'Add manually';
          _customTypeController.text = optionType;
          _isCustomType = true;
          debugPrint('Custom option type set to: $optionType');
        }
      }

      if (extractedData['status'] != null) {
        debugPrint(
            'Setting option status from extracted data: ${extractedData['status']}');
        final status = extractedData['status'].toString().toLowerCase();
        if (status.contains('postponed')) {
          _selectedOptionStatus = OptionStatus.postponed;
        } else if (status.contains('declined')) {
          _selectedOptionStatus = OptionStatus.declined;
        } else if (status.contains('canceled') ||
            status.contains('cancelled')) {
          _selectedOptionStatus = OptionStatus.clientCanceled;
        } else {
          _selectedOptionStatus = OptionStatus.pending;
        }
        debugPrint('Option status set to: $_selectedOptionStatus');
      }

      if (extractedData['currency'] != null) {
        debugPrint('Setting currency: ${extractedData['currency']}');
        _selectedCurrency = extractedData['currency'];
      }

      if (extractedData['agencyFee'] != null) {
        debugPrint('Setting agency fee: ${extractedData['agencyFee']}');
        _agencyFeeController.text = extractedData['agencyFee'].toString();
      } else if (_agencyFeeController.text.isEmpty) {
        _agencyFeeController.text = '20';
        debugPrint('Setting default agency fee to 20%');
      }

      if (extractedData['callTime'] != null) {
        debugPrint('Setting call time: ${extractedData['callTime']}');
        // Add call time to notes if not already there
        final callTimeInfo = 'Call time: ${extractedData['callTime']}';
        if (!_notesController.text.contains(callTimeInfo)) {
          if (_notesController.text.isNotEmpty) {
            _notesController.text += '\n\n$callTimeInfo';
          } else {
            _notesController.text = callTimeInfo;
          }
        }
      }

      // Apply smart defaults based on extracted data context
      _applySmartDefaults(extractedData);
    });

    // Add ALL extracted data to notes for complete record
    _appendAllExtractedDataToNotes(extractedData);

    // Handle agent matching after setState (async operation)
    if (extractedData['bookingAgent'] != null) {
      debugPrint('🔍 Now matching agent: ${extractedData['bookingAgent']}');
      await _matchAgentIntelligently(extractedData['bookingAgent'].toString());
    }

    debugPrint('=== DIRECT OPTIONS FORM UPDATE COMPLETE ===');
  }

  /// Apply smart defaults based on extracted data context
  void _applySmartDefaults(Map<String, dynamic> extractedData) {
    debugPrint('🧠 Applying smart defaults for direct option...');

    // Extract common variables for use throughout the method
    final clientName =
        extractedData['clientName']?.toString().toLowerCase() ?? '';
    final notes = extractedData['notes']?.toString().toLowerCase() ?? '';
    final jobTitle = extractedData['jobTitle']?.toString().toLowerCase() ?? '';

    // Smart option type detection
    if (_selectedOptionType.isEmpty) {
      // Detect option type from context
      if (clientName.contains('samsung') ||
          jobTitle.contains('galaxy') ||
          notes.contains('commercial')) {
        _selectedOptionType = 'Commercial';
        _isCustomType = false;
        debugPrint('🧠 Smart default: Commercial option detected');
      } else if (notes.contains('editorial') || notes.contains('magazine')) {
        _selectedOptionType = 'Editorial';
        _isCustomType = false;
        debugPrint('🧠 Smart default: Editorial option detected');
      } else if (notes.contains('fashion') || notes.contains('runway')) {
        _selectedOptionType = 'Fashion Show';
        _isCustomType = false;
        debugPrint('🧠 Smart default: Fashion option detected');
      } else if (notes.contains('social') || notes.contains('instagram')) {
        _selectedOptionType = 'Social Media';
        _isCustomType = false;
        debugPrint('🧠 Smart default: Social Media option detected');
      } else {
        // Default to custom type
        _selectedOptionType = 'Add manually';
        _isCustomType = true;
        _customTypeController.text = 'Commercial';
        debugPrint('🧠 Smart default: Custom Commercial option');
      }
    }

    // Smart currency based on location or client
    if (_selectedCurrency == 'USD') {
      final location =
          extractedData['location']?.toString().toLowerCase() ?? '';
      final clientName =
          extractedData['clientName']?.toString().toLowerCase() ?? '';

      if (location.contains('europe') ||
          location.contains('poland') ||
          location.contains('germany') ||
          clientName.contains('samsung') ||
          extractedData['currency']?.toString() == 'EUR') {
        _selectedCurrency = 'EUR';
        debugPrint('🧠 Smart default: EUR currency detected');
      } else if (location.contains('uk') || location.contains('london')) {
        _selectedCurrency = 'GBP';
        debugPrint('🧠 Smart default: GBP currency detected');
      }
    }

    // Smart option status based on context
    if (notes.contains('declined') || notes.contains('rejected')) {
      _selectedOptionStatus = OptionStatus.declined;
      debugPrint('🧠 Smart default: Declined status detected');
    } else if (notes.contains('postponed') || notes.contains('delayed')) {
      _selectedOptionStatus = OptionStatus.postponed;
      debugPrint('🧠 Smart default: Postponed status detected');
    } else if (notes.contains('canceled') || notes.contains('cancelled')) {
      _selectedOptionStatus = OptionStatus.clientCanceled;
      debugPrint('🧠 Smart default: Client canceled status detected');
    } else {
      _selectedOptionStatus = OptionStatus.pending;
      debugPrint('🧠 Smart default: Pending status (default)');
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

  Future<void> _loadDirectOption(String id) async {
    setState(() {
      _isLoading = true;
      _isEditing = true;
      _editingId = id;
    });

    try {
      final option = await DirectOptionsService.getById(id);
      if (option != null) {
        setState(() {
          _clientNameController.text = option.clientName;
          _selectedOptionType = option.optionType ?? '';
          _locationController.text = option.location ?? '';
          _dayRateController.text = option.rate?.toString() ?? '';
          _selectedDate = option.date ?? DateTime.now();
          _notesController.text = option.notes ?? '';
          // Convert status string to OptionStatus enum
          _selectedOptionStatus = OptionStatus.values.firstWhere(
            (status) => status.toString().split('.').last == option.status,
            orElse: () => OptionStatus.pending,
          );
          _selectedCurrency = option.currency ?? 'USD';
          _agencyFeeController.text = option.agencyFeePercentage ?? '';
          _selectedAgentId = option.bookingAgent;

          // Handle custom type
          if (_selectedOptionType.isNotEmpty &&
              !_optionTypes.contains(_selectedOptionType)) {
            _customTypeController.text = _selectedOptionType;
            _selectedOptionType = 'Add manually';
            _isCustomType = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading direct option: $e'),
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

  @override
  void dispose() {
    _clientNameController.dispose();
    _locationController.dispose();
    _dayRateController.dispose();
    _usageRateController.dispose();
    _notesController.dispose();
    _customTypeController.dispose();
    _agencyFeeController.dispose();
    _transferToDirectBookingController.dispose();
    _formNavigation.dispose();

    // Dispose manual focus nodes
    for (final focusNode in _manualFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  // Time-related methods removed as they're not needed for direct options

  Future<void> _selectStartDate() async {
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
        // Clear end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _selectedDate.add(const Duration(days: 1)),
      firstDate: _selectedDate,
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
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _transferToDirectBooking() async {
    try {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Transfer to Direct Booking',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to convert this option to a direct booking? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldColor,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Transfer'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        setState(() {
          _isLoading = true;
        });

        // Create direct booking data from current option data
        final directBookingData = {
          'client': _clientNameController.text,
          'option_type': _selectedOptionType,
          'date': _selectedDate.toIso8601String().split('T')[0],
          'location': _locationController.text,
          'agent_id': _selectedAgentId,
          'day_rate': double.tryParse(_dayRateController.text),
          'usage_rate': double.tryParse(_usageRateController.text),
          'currency': _selectedCurrency,
          'notes': _notesController.text,
          'agency_fee_percentage': _agencyFeeController.text,
          'status': 'Confirmed',
          'payment_status': 'Unpaid',
          'transferred_from_option': _editingId,
        };

        // Add end date if it's a date range
        if (_isDateRange && _endDate != null) {
          directBookingData['end_date'] =
              _endDate!.toIso8601String().split('T')[0];
          directBookingData['is_multi_day'] = true;
        }

        // Add file data if available
        if (_selectedFiles.isNotEmpty) {
          final fileData = <String, dynamic>{};
          for (int i = 0; i < _selectedFiles.length; i++) {
            final file = _selectedFiles[i];
            fileData['file_${i + 1}_name'] = file.name;
            fileData['file_${i + 1}_size'] = file.size;
          }
          directBookingData['file_data'] = fileData;
        }

        // Save the direct booking (using DirectOptionsService for now)
        // Note: You may need to create a DirectBookingService or use the appropriate service
        await DirectOptionsService.create(directBookingData);

        // Update the original option status to 'transferred'
        await DirectOptionsService.update(_editingId!, {
          'status': 'transferred_to_direct_booking',
          'transfer_date': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully transferred to direct booking!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to the events list
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error transferring to direct booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // File handling methods
  Future<void> _pickFiles() async {
    try {
      final files = await FileUploadService.pickDocumentAndImageFiles(
        allowMultiple: true,
      );

      if (files != null && files.isNotEmpty) {
        // Validate file sizes
        final validFiles = <PlatformFile>[];
        for (final file in files) {
          if (FileUploadService.isFileSizeValid(file.size)) {
            validFiles.add(file);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File "${file.name}" is too large (max 50MB)'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(validFiles);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate option ID for file organization
      final optionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload files to Firebase Storage if any
      Map<String, dynamic>? fileData;
      if (_selectedFiles.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(width: 16),
                  Text('Uploading ${_selectedFiles.length} files...'),
                ],
              ),
              duration: const Duration(seconds: 30),
            ),
          );
        }

        final downloadUrls = await FileUploadService.uploadMultipleFiles(
          files: _selectedFiles,
          eventId: optionId,
          eventType: 'direct_option',
        );

        if (downloadUrls.length != _selectedFiles.length) {
          throw Exception(
              'Failed to upload all files. Only ${downloadUrls.length}/${_selectedFiles.length} uploaded.');
        }

        fileData = FileUploadService.createFileData(
          downloadUrls: downloadUrls,
          originalFiles: _selectedFiles,
        );
      }

      final optionData = {
        'client_name': _clientNameController.text,
        'option_type':
            _isCustomType ? _customTypeController.text : _selectedOptionType,
        'day_rate': double.tryParse(_dayRateController.text),
        'usage_rate': double.tryParse(_usageRateController.text),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'location': _locationController.text,
        'booking_agent': _selectedAgentId,
        'option_status': _selectedOptionStatus.toString().split('.').last,
        'currency': _selectedCurrency,
        'notes': _notesController.text,
        'agency_fee_percentage': _agencyFeeController.text,
        'option_id': optionId,
        'is_multi_day': _isDateRange,
        if (_isEditing)
          'transfer_to_direct_booking': _transferToDirectBookingController.text,
      };

      // Add end date if it's a date range
      if (_isDateRange && _endDate != null) {
        optionData['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
      }

      // Add file data if files were uploaded
      if (fileData != null) {
        optionData['file_data'] = fileData;
      }

      if (_isEditing && _editingId != null) {
        final result =
            await DirectOptionsService.update(_editingId!, optionData);
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Direct option updated successfully!'),
              backgroundColor: AppTheme.goldColor,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else if (mounted) {
          throw Exception('Failed to update direct option');
        }
      } else {
        final result = await DirectOptionsService.create(optionData);
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Direct option created successfully!'),
              backgroundColor: AppTheme.goldColor,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else if (mounted) {
          throw Exception('Failed to create direct option');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving direct option: $e'),
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

  Future<void> _handleOptionConfirmation() async {
    debugPrint('🎯 Option confirmed! Converting to appropriate event...');

    // Show confirmation dialog
    final shouldConvert = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Confirm Option',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This option will be converted to a job/event. This action cannot be undone. Continue?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldConvert == true) {
      await _convertOptionToEvent();
    } else {
      // Revert status back to pending if user cancels
      setState(() {
        _selectedOptionStatus = OptionStatus.pending;
      });
    }
  }

  Future<void> _convertOptionToEvent() async {
    try {
      debugPrint('🔄 Converting option to event...');

      // Determine event type based on option type
      EventType eventType = _getEventTypeFromOptionType(_selectedOptionType);

      // Create event data from current option data
      final eventData = {
        'client_name': _clientNameController.text,
        'job_type': _selectedOptionType,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'location': _locationController.text,
        'agent_id': _selectedAgentId,
        'day_rate': double.tryParse(_dayRateController.text),
        'currency': _selectedCurrency,
        'status': 'scheduled',
        'payment_status': 'unpaid',
        'notes':
            '${_notesController.text}\n\n[Converted from confirmed option]',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Add end date if it's a date range
      if (_isDateRange && _endDate != null) {
        eventData['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
      }

      // Create the event in the appropriate collection
      String? eventId = await _createEventInCollection(eventType, eventData);

      if (eventId != null) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Option confirmed and converted to ${eventType.displayName}!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back or to the new event
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to create event');
      }
    } catch (e) {
      debugPrint('❌ Error converting option to event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error converting option: $e'),
            backgroundColor: Colors.red,
          ),
        );

        // Revert status back to pending
        setState(() {
          _selectedOptionStatus = OptionStatus.pending;
        });
      }
    }
  }

  EventType _getEventTypeFromOptionType(String optionType) {
    switch (optionType.toLowerCase()) {
      case 'commercial':
      case 'editorial':
      case 'lookbook':
      case 'print':
      case 'web content':
      case 'social media':
        return EventType.job;
      case 'fashion show':
      case 'runway':
        return EventType.casting;
      case 'on stay':
      case 'onstay':
      case 'travel':
      case 'accommodation':
      case 'hotel':
        return EventType.onStay;
      case 'other':
        return EventType.other;
      default:
        return EventType.job; // Default to job
    }
  }

  Future<String?> _createEventInCollection(
      EventType eventType, Map<String, dynamic> eventData) async {
    try {
      switch (eventType) {
        case EventType.job:
          // Create in jobs collection
          final docRef = await FirebaseFirestore.instance
              .collection('jobs')
              .add(eventData);
          return docRef.id;
        case EventType.casting:
          // Create in castings collection
          final docRef = await FirebaseFirestore.instance
              .collection('castings')
              .add(eventData);
          return docRef.id;
        case EventType.onStay:
          // Create in on_stay collection with OnStay-specific format
          final onStayData = {
            'location_name':
                eventData['client_name'], // Use client name as location
            'stay_type': 'On Stay',
            'address': eventData['location'],
            'check_in_date': eventData['date'],
            'check_out_date': eventData['end_date'],
            'cost': eventData['day_rate'] ?? 0.0,
            'currency': eventData['currency'] ?? 'USD',
            'contact_name': eventData['client_name'],
            'agent_id': eventData['agent_id'],
            'status': 'confirmed',
            'payment_status': 'unpaid',
            'notes': eventData['notes'],
            'created_at': eventData['created_at'],
            'updated_at': eventData['updated_at'],
          };
          final docRef = await FirebaseFirestore.instance
              .collection('on_stay')
              .add(onStayData);
          return docRef.id;
        case EventType.other:
          // Create in events collection with type 'other'
          eventData['type'] = 'other';
          final docRef = await FirebaseFirestore.instance
              .collection('events')
              .add(eventData);
          return docRef.id;
        default:
          // Create in events collection
          eventData['type'] = eventType.toString().split('.').last;
          final docRef = await FirebaseFirestore.instance
              .collection('events')
              .add(eventData);
          return docRef.id;
      }
    } catch (e) {
      debugPrint('❌ Error creating event in collection: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building NewDirectOptionPage, _isEditing: $_isEditing');
    debugPrint('OCR Widget will be shown: ${!_isEditing}');
    if (_isLoading && _isEditing) {
      return AppLayout(
        currentPage: '/new-direct-option',
        title: _isEditing ? 'Edit Direct Option' : 'New Direct Option',
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AppLayout(
      currentPage: '/new-direct-option',
      title: _isEditing ? 'Edit Direct Option' : 'New Direct Option',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new options (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  // Auto-submit disabled for testing
                  // onAutoSubmit: () {
                  //   debugPrint('Auto-submitting form after OCR...');
                  //   _handleSubmit();
                  // },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information Section
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
                  _buildOptionTypeField(),
                  const SizedBox(height: 16),
                  _buildDateField(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    focusNode: _manualFocusNodes[2], // Location
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
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

              // Rates and Status Section
              _buildSectionCard(
                'Rates and Status',
                [
                  _buildRateFields(),
                  const SizedBox(height: 16),
                  _buildOptionStatusField(),
                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppTheme.goldColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[900],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.transform,
                                color: AppTheme.goldColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Transfer to Direct Booking',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.goldColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Convert this option to a confirmed direct booking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _transferToDirectBooking,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Transfer to Direct Booking'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.goldColor,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _formNavigation.createInputField(
                    label: 'Agency Fee (%)',
                    controller: _agencyFeeController,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Files Section
              _buildFileUploadSection(),
              const SizedBox(height: 24),

              // Notes Section
              _buildSectionCard(
                'Notes',
                [
                  TextFormField(
                    controller: _notesController,
                    focusNode: _manualFocusNodes[5], // Notes
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
                          : (_isEditing ? 'Update Option' : 'Create Option'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust padding based on available width
        final isSmallScreen = constraints.maxWidth < 400;
        final padding = isSmallScreen ? 12.0 : 20.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2E2E2E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Option Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (_isCustomType)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _customTypeController,
                  focusNode: _manualFocusNodes[1], // Custom Option Type
                  decoration: const InputDecoration(
                    labelText: 'Custom Option Type',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter option type';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () {
                  setState(() {
                    _isCustomType = false;
                    _customTypeController.clear();
                  });
                },
                text: 'Cancel',
                variant: ButtonVariant.outline,
              ),
            ],
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2E2E2E)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedOptionType.isNotEmpty &&
                      _optionTypes.contains(_selectedOptionType)
                  ? _selectedOptionType
                  : null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              dropdownColor: Colors.black,
              style: const TextStyle(color: Colors.white),
              hint: const Text(
                'Select option type',
                style: TextStyle(color: Colors.white70),
              ),
              items: _optionTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == 'Add manually') {
                  setState(() {
                    _isCustomType = true;
                    _selectedOptionType = '';
                  });
                } else {
                  setState(() {
                    _selectedOptionType = value ?? '';
                  });
                }
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
          'Date Range',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Date Range Selection
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectStartDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isDateRange) ...[
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward, color: Colors.white70),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2E2E2E)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white70),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _endDate != null
                                ? DateFormat('MMM d, yyyy').format(_endDate!)
                                : 'Select end date',
                            style: TextStyle(
                              color: _endDate != null
                                  ? Colors.white
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Date Range Toggle
        CheckboxListTile(
          title: const Text(
            'Multi-day Option',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: const Text(
            'Enable for options spanning multiple days',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          value: _isDateRange,
          onChanged: (value) {
            setState(() {
              _isDateRange = value ?? false;
              if (!_isDateRange) {
                _endDate = null;
              }
            });
          },
          activeColor: AppTheme.goldColor,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildRateFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _dayRateController,
                focusNode: _manualFocusNodes[3], // Day Rate
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Day Rate',
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
                          : 'USD',
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
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _usageRateController,
          focusNode: _manualFocusNodes[4], // Usage Rate
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Usage Rate (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Option Status',
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
          child: DropdownButtonFormField<OptionStatus>(
            initialValue: _selectedOptionStatus,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
            items: OptionStatus.values.map((status) {
              return DropdownMenuItem<OptionStatus>(
                value: status,
                child: Text(
                  status.displayName,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedOptionStatus = value ?? OptionStatus.pending;
              });

              // Check if status changed to confirmed
              if (value == OptionStatus.confirmed) {
                _handleOptionConfirmation();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    return _buildSectionCard(
      'Files',
      [
        Row(
          children: [
            const Icon(Icons.attach_file, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'Files',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add),
              label: const Text('Add Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldColor,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        if (_selectedFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(_selectedFiles.length, (index) {
            final file = _selectedFiles[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[600]!),
              ),
              child: Row(
                children: [
                  Text(
                    FileUploadService.getFileIcon(file.extension),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          FileUploadService.getFileSize(file.size),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeFile(index),
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.red,
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            'No files selected. You can upload contracts, invoices, schedules, and other documents.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}
