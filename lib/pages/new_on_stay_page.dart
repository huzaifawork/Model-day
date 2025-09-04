import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/models/on_stay.dart';
import 'package:new_flutter/services/on_stay_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';

import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:intl/intl.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:new_flutter/services/file_upload_service.dart';

class NewOnStayPage extends StatefulWidget {
  final OnStay? stay; // For editing existing stays

  const NewOnStayPage({super.key, this.stay});

  @override
  State<NewOnStayPage> createState() => _NewOnStayPageState();
}

class _NewOnStayPageState extends State<NewOnStayPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  final _agencyNameController = TextEditingController();
  final _agencyAddressController = TextEditingController();
  final _locationController = TextEditingController();
  final _contractController = TextEditingController();
  final _flightCostController = TextEditingController();
  final _hotelAddressController = TextEditingController();
  final _hotelCostController = TextEditingController();
  final _pocketMoneyCostController = TextEditingController();
  final _notesController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  // Field navigation

  // Manual focus nodes for better control
  late List<FocusNode> _manualFocusNodes;

  // Form state
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAgentId;
  bool _hasPocketMoney = false;
  bool _loading = false;

  // File upload state
  final List<PlatformFile> _contractFiles = [];
  final List<PlatformFile> _flightFiles = [];

  // No dropdown options needed for this simplified form

  @override
  void initState() {
    super.initState();

    // Initialize manual focus nodes for text fields (7 text fields: Agency Name, Agency Address, Location, Contract Details, Hotel Address, Hotel Cost, Pocket Money Cost, Notes)
    _manualFocusNodes = List.generate(8, (index) => FocusNode());

    // Try to populate immediately if widget.stay is available
    if (widget.stay != null) {
      debugPrint(
          '🏨 OnStay initState - Populating form immediately from widget');
      _populateForm(widget.stay!);
    }

    // Handle both widget.stay and route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Add a small delay to ensure the widget is fully built
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint(
          '🏨 NewOnStayPage postFrameCallback - Arguments type: ${args.runtimeType}');
      debugPrint(
          '🏨 NewOnStayPage postFrameCallback - Widget stay: ${widget.stay}');

      if (args is OnStay) {
        debugPrint(
            '🏨 NewOnStayPage postFrameCallback - Populating from route arguments');
        debugPrint(
            '🏨 Route args OnStay data: id=${args.id}, locationName=${args.locationName}, contactName=${args.contactName}');
        _populateForm(args);
      } else if (widget.stay != null) {
        debugPrint(
            '🏨 NewOnStayPage postFrameCallback - Re-populating from widget stay');
        debugPrint(
            '🏨 Widget OnStay data: id=${widget.stay!.id}, locationName=${widget.stay!.locationName}, contactName=${widget.stay!.contactName}');
        _populateForm(widget.stay!);
      } else {
        debugPrint(
            '🏨 NewOnStayPage postFrameCallback - No stay data to populate');
        debugPrint('🏨 Args value: $args');
      }
    });
  }

  void _populateForm(OnStay stay) {
    debugPrint(
        '🏨 Populating form with stay: ${stay.locationName} (${stay.id})');
    debugPrint(
        '🏨 Stay data: location=${stay.locationName}, address=${stay.address}, cost=${stay.cost}');
    debugPrint('🏨 Stay contactName: ${stay.contactName}');
    debugPrint('🏨 Stay checkInDate: ${stay.checkInDate}');
    debugPrint('🏨 Stay checkOutDate: ${stay.checkOutDate}');
    debugPrint('🏨 Stay notes: ${stay.notes}');

    setState(() {
      // Map existing OnStay fields to new form structure
      _locationController.text = stay.locationName;
      _hotelAddressController.text = stay.address ?? '';
      _startDate = stay.checkInDate;
      _endDate = stay.checkOutDate;
      _hotelCostController.text = stay.cost.toString();
      _notesController.text = stay.notes ?? '';

      // Set contact name if available
      if (stay.contactName != null && stay.contactName!.isNotEmpty) {
        _agencyNameController.text = stay.contactName!;
        debugPrint('🏨 Set agency name to: ${stay.contactName}');
      } else {
        debugPrint('🏨 No contact name available');
      }

      // Set agent ID if available
      if (stay.agentId != null && stay.agentId!.isNotEmpty) {
        _selectedAgentId = stay.agentId;
        debugPrint('🏨 Set agent ID to: ${stay.agentId}');
      } else {
        debugPrint('🏨 No agent ID available');
      }

      // Parse structured notes back into individual fields
      _parseNotesIntoFields(stay.notes ?? '');
    });

    debugPrint('🏨 Form populated successfully');
    debugPrint('🏨 Location Controller: ${_locationController.text}');
    debugPrint('🏨 Hotel Address Controller: ${_hotelAddressController.text}');
    debugPrint('🏨 Agency Name Controller: ${_agencyNameController.text}');
    debugPrint('🏨 Hotel Cost Controller: ${_hotelCostController.text}');
    debugPrint('🏨 Start Date: $_startDate');
    debugPrint('🏨 End Date: $_endDate');
  }

  void _parseNotesIntoFields(String notes) {
    if (notes.isEmpty) return;

    debugPrint('🏨 Parsing notes into individual fields: $notes');

    // Split notes by double newlines to get individual sections
    final sections = notes.split('\n\n');

    for (final section in sections) {
      final trimmedSection = section.trim();

      if (trimmedSection.startsWith('Agency: ')) {
        final agencyName = trimmedSection.substring(8).trim();
        if (agencyName.isNotEmpty && _agencyNameController.text.isEmpty) {
          _agencyNameController.text = agencyName;
          debugPrint('🏨 Parsed agency name: $agencyName');
        }
      } else if (trimmedSection.startsWith('Agency Address: ')) {
        final agencyAddress = trimmedSection.substring(16).trim();
        if (agencyAddress.isNotEmpty) {
          _agencyAddressController.text = agencyAddress;
          debugPrint('🏨 Parsed agency address: $agencyAddress');
        }
      } else if (trimmedSection.startsWith('Contract: ')) {
        final contract = trimmedSection.substring(10).trim();
        if (contract.isNotEmpty) {
          _contractController.text = contract;
          debugPrint('🏨 Parsed contract: $contract');
        }
      } else if (trimmedSection.startsWith('Flight Cost: ')) {
        final flightCost = trimmedSection.substring(13).trim();
        if (flightCost.isNotEmpty) {
          _flightCostController.text = flightCost;
          debugPrint('🏨 Parsed flight cost: $flightCost');
        }
      } else if (trimmedSection.startsWith('Pocket Money: ')) {
        final pocketMoney = trimmedSection.substring(14).trim();
        if (pocketMoney.isNotEmpty) {
          _hasPocketMoney = true;
          _pocketMoneyCostController.text = pocketMoney;
          debugPrint('🏨 Parsed pocket money: $pocketMoney');
        }
      } else if (trimmedSection.startsWith('Additional Notes: ')) {
        final additionalNotes = trimmedSection.substring(18).trim();
        if (additionalNotes.isNotEmpty) {
          _notesController.text = additionalNotes;
          debugPrint('🏨 Parsed additional notes: $additionalNotes');
        }
      }
    }
  }

  // OCR data extraction handler - similar to job page
  Future<void> _handleOcrDataExtracted(
      Map<String, dynamic> extractedData) async {
    debugPrint('=== ON STAY PAGE FORM HANDLER CALLED ===');
    debugPrint('OCR Data received: $extractedData');
    debugPrint('Keys received: ${extractedData.keys.toList()}');
    setState(() {
      // Set dates from extracted data or use defaults
      if (extractedData['checkInDate'] != null) {
        try {
          _startDate = DateTime.parse(extractedData['checkInDate']);
          debugPrint('Setting check-in date from OCR: $_startDate');
        } catch (e) {
          _startDate = DateTime.now();
          debugPrint(
              'Failed to parse check-in date, using current date: $_startDate');
        }
      } else {
        _startDate = DateTime.now();
      }

      if (extractedData['checkOutDate'] != null) {
        try {
          _endDate = DateTime.parse(extractedData['checkOutDate']);
          debugPrint('Setting check-out date from OCR: $_endDate');
        } catch (e) {
          _endDate = DateTime.now().add(const Duration(days: 2));
          debugPrint(
              'Failed to parse check-out date, using current date + 2 days: $_endDate');
        }
      } else {
        _endDate = DateTime.now().add(const Duration(days: 2));
      }

      // Populate form fields with extracted data
      // Try multiple field names for agency name
      String? agencyName;
      if (extractedData['agencyName'] != null) {
        agencyName = extractedData['agencyName'];
      } else if (extractedData['clientName'] != null) {
        agencyName = extractedData['clientName'];
      } else if (extractedData['client'] != null) {
        agencyName = extractedData['client'];
      } else if (extractedData['company'] != null) {
        agencyName = extractedData['company'];
      } else if (extractedData['studio'] != null) {
        agencyName = extractedData['studio'];
      }

      if (agencyName != null) {
        debugPrint('Setting agency name: $agencyName');
        _agencyNameController.text = agencyName;
      } else {
        // Extract from location or notes if no direct agency name found
        if (extractedData['location'] != null) {
          final locationText = extractedData['location'].toString();
          if (locationText.contains('Elite Fashion Studios') ||
              locationText.contains('Fashion Studios')) {
            _agencyNameController.text = 'Elite Fashion Studios';
            debugPrint(
                'Setting agency name from location: Elite Fashion Studios');
          } else if (locationText.contains('Studio')) {
            // Extract studio name from location
            final words = locationText.split(' ');
            final studioIndex = words
                .indexWhere((word) => word.toLowerCase().contains('studio'));
            if (studioIndex > 0) {
              final studioName = words.sublist(0, studioIndex + 1).join(' ');
              _agencyNameController.text = studioName;
              debugPrint(
                  'Setting agency name from studio location: $studioName');
            }
          }
        }
      }
      if (extractedData['location'] != null) {
        debugPrint('Setting location: ${extractedData['location']}');
        _locationController.text = extractedData['location'];
      }
      // Enhanced address extraction
      if (extractedData['address'] != null ||
          extractedData['hotelAddress'] != null ||
          extractedData['hotelLocation'] != null) {
        final address = extractedData['hotelAddress'] ??
            extractedData['address'] ??
            extractedData['hotelLocation'];
        debugPrint('Setting hotel address: $address');
        _hotelAddressController.text = address;
      }

      // Enhanced agency address extraction
      if (extractedData['agencyAddress'] != null ||
          extractedData['companyAddress'] != null ||
          extractedData['studioAddress'] != null) {
        final agencyAddress = extractedData['agencyAddress'] ??
            extractedData['companyAddress'] ??
            extractedData['studioAddress'];
        debugPrint('Setting agency address: $agencyAddress');
        _agencyAddressController.text = agencyAddress;
      } else if (extractedData['location'] != null &&
          _agencyAddressController.text.isEmpty) {
        // Use location as fallback for agency address
        debugPrint(
            'Setting agency address from location: ${extractedData['location']}');
        _agencyAddressController.text = extractedData['location'];
      }
      if (extractedData['notes'] != null) {
        debugPrint('Setting notes: ${extractedData['notes']}');
        _notesController.text = extractedData['notes'];
      }

      // Handle accommodation-specific fields
      if (extractedData['checkInDate'] != null) {
        debugPrint('Setting check-in date: ${extractedData['checkInDate']}');
        try {
          _startDate = DateTime.parse(extractedData['checkInDate']);
        } catch (e) {
          debugPrint('Error parsing check-in date: $e');
        }
      }

      if (extractedData['checkOutDate'] != null) {
        debugPrint('Setting check-out date: ${extractedData['checkOutDate']}');
        try {
          _endDate = DateTime.parse(extractedData['checkOutDate']);
        } catch (e) {
          debugPrint('Error parsing check-out date: $e');
        }
      }

      if (extractedData['hotelAddress'] != null) {
        debugPrint('Setting hotel address: ${extractedData['hotelAddress']}');
        _hotelAddressController.text = extractedData['hotelAddress'];
      }

      if (extractedData['hotelCost'] != null) {
        debugPrint('Setting hotel cost: ${extractedData['hotelCost']}');
        _hotelCostController.text = extractedData['hotelCost'].toString();
      }

      if (extractedData['pocketMoney'] != null) {
        debugPrint('Setting pocket money: ${extractedData['pocketMoney']}');
        _pocketMoneyCostController.text =
            extractedData['pocketMoney'].toString();
      }

      if (extractedData['agencyName'] != null) {
        debugPrint('Setting agency name: ${extractedData['agencyName']}');
        _agencyNameController.text = extractedData['agencyName'];
      }

      if (extractedData['agencyAddress'] != null) {
        debugPrint('Setting agency address: ${extractedData['agencyAddress']}');
        _agencyAddressController.text = extractedData['agencyAddress'];
      }

      if (extractedData['contractDetails'] != null) {
        debugPrint(
            'Setting contract details: ${extractedData['contractDetails']}');
        _contractController.text = extractedData['contractDetails'];
      }
      // Enhanced hotel cost extraction with multiple field names
      String? hotelCostValue;
      if (extractedData['hotelCost'] != null) {
        hotelCostValue = extractedData['hotelCost'].toString();
      } else if (extractedData['cost'] != null) {
        hotelCostValue = extractedData['cost'].toString();
      } else if (extractedData['rate'] != null) {
        hotelCostValue = extractedData['rate'].toString();
      } else if (extractedData['price'] != null) {
        hotelCostValue = extractedData['price'].toString();
      } else if (extractedData['fee'] != null) {
        hotelCostValue = extractedData['fee'].toString();
      } else if (extractedData['dayRate'] != null) {
        hotelCostValue = extractedData['dayRate'].toString();
      }

      if (hotelCostValue != null) {
        debugPrint('Setting hotel cost: $hotelCostValue');
        // Clean the cost value (remove currency symbols, commas, etc.)
        final cleanCost = hotelCostValue.replaceAll(RegExp(r'[^\d.]'), '');
        if (cleanCost.isNotEmpty) {
          _hotelCostController.text = cleanCost;
        }
      }

      // Enhanced flight cost extraction
      if (extractedData['flightCost'] != null) {
        debugPrint('Setting flight cost: ${extractedData['flightCost']}');
        final cleanFlightCost = extractedData['flightCost']
            .toString()
            .replaceAll(RegExp(r'[^\d.]'), '');
        if (cleanFlightCost.isNotEmpty) {
          _flightCostController.text = cleanFlightCost;
        }
      }
      if (extractedData['contractDetails'] != null) {
        debugPrint(
            'Setting contract details: ${extractedData['contractDetails']}');
        _contractController.text = extractedData['contractDetails'];
      }
      // Enhanced pocket money extraction
      if (extractedData['pocketMoney'] != null) {
        final pocketMoney = extractedData['pocketMoney'].toString();
        if (pocketMoney.toLowerCase().contains('yes') ||
            pocketMoney.toLowerCase().contains('true') ||
            pocketMoney.toLowerCase().contains('included')) {
          _hasPocketMoney = true;
          debugPrint('Setting pocket money to: true');
        }
      }

      // Extract pocket money cost with multiple field names
      if (extractedData['pocketMoneyCost'] != null ||
          extractedData['pocketMoneyAmount'] != null ||
          extractedData['allowance'] != null) {
        final pocketMoneyCost = extractedData['pocketMoneyCost'] ??
            extractedData['pocketMoneyAmount'] ??
            extractedData['allowance'];
        debugPrint('Setting pocket money cost: $pocketMoneyCost');
        final cleanPocketMoney =
            pocketMoneyCost.toString().replaceAll(RegExp(r'[^\d.]'), '');
        if (cleanPocketMoney.isNotEmpty) {
          _hasPocketMoney = true;
          _pocketMoneyCostController.text = cleanPocketMoney;
        }
      }

      // Extract additional fields that might be missing
      if (extractedData['description'] != null &&
          _notesController.text.isEmpty) {
        debugPrint(
            'Setting notes from description: ${extractedData['description']}');
        _notesController.text = extractedData['description'];
      }

      // Extract contract details with alternative field names
      if (extractedData['contract'] != null &&
          _contractController.text.isEmpty) {
        debugPrint(
            'Setting contract from contract field: ${extractedData['contract']}');
        _contractController.text = extractedData['contract'];
      }
      // Agent matching moved outside setState - see below
      if (extractedData['bookingAgent'] != null ||
          extractedData['agent'] != null) {
        debugPrint('✅ Agent will be set after setState');
      } else {
        debugPrint('❌ No agent found in OCR data');
      }
    });
    debugPrint('✅ OCR data extraction completed for on stay');

    // Add ALL extracted data to notes for complete record
    _appendAllExtractedDataToNotes(extractedData);

    // Handle agent matching after setState (async operation)
    if (extractedData['bookingAgent'] != null ||
        extractedData['agent'] != null) {
      final agentName = extractedData['bookingAgent'] ?? extractedData['agent'];
      debugPrint('🔍 Now matching agent: $agentName');
      await _matchAgentIntelligently(agentName.toString());
    }

    // Auto-submit disabled for testing
    // Future.delayed(const Duration(milliseconds: 1500), () {
    //   debugPrint('🚀 Auto-submitting on stay after OCR...');
    //   _saveStay();
    // });
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

  @override
  void dispose() {
    _agencyNameController.dispose();
    _agencyAddressController.dispose();
    _locationController.dispose();
    _contractController.dispose();
    _flightCostController.dispose();
    _hotelAddressController.dispose();
    _hotelCostController.dispose();
    _pocketMoneyCostController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    _formNavigation.dispose();

    // Dispose manual focus nodes
    for (final focusNode in _manualFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final isEditing = args is OnStay || widget.stay != null;

    debugPrint('🏨 OnStay build() called - isEditing: $isEditing');
    debugPrint(
        '🏨 OnStay build() - Agency Name Controller: ${_agencyNameController.text}');
    debugPrint(
        '🏨 OnStay build() - Location Controller: ${_locationController.text}');

    return AppLayout(
      currentPage: '/new-on-stay',
      title: isEditing ? 'Edit Stay' : 'New Stay',
      child: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // OCR Widget for new on stays (not when editing)
                if (!isEditing) ...[
                  OcrUploadWidget(
                    onDataExtracted: (data) {
                      debugPrint('OCR Widget callback received data: $data');
                      _handleOcrDataExtracted(data);
                    },
                    // Auto-submit disabled for testing
                    // onAutoSubmit: () {
                    //   debugPrint('Auto-submitting on stay form after OCR...');
                    //   _saveStay();
                    // },
                  ),
                  const SizedBox(height: 24),
                ],
                _buildAgencySection(),
                const SizedBox(height: 24),
                _buildDatesSection(),
                const SizedBox(height: 24),
                _buildLocationSection(),
                const SizedBox(height: 24),
                _buildAgentSection(),
                const SizedBox(height: 24),
                _buildContractSection(),
                const SizedBox(height: 24),
                _buildFlightsSection(),
                const SizedBox(height: 24),
                _buildHotelSection(),
                const SizedBox(height: 24),
                _buildPocketMoneySection(),
                const SizedBox(height: 24),
                _buildNotesSection(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgencySection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agency Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _agencyNameController,
              focusNode: _manualFocusNodes[0], // Agency Name
              decoration: const InputDecoration(
                labelText: 'Agency Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Agency name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _agencyAddressController,
              focusNode: _manualFocusNodes[1], // Agency Address
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Agency Address *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Agency address is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _startDate != null
                            ? DateFormat('MMM d, yyyy').format(_startDate!)
                            : 'Select start date',
                        style: TextStyle(
                          color:
                              _startDate != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormat('MMM d, yyyy').format(_endDate!)
                            : 'Select end date',
                        style: TextStyle(
                          color: _endDate != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              focusNode: _manualFocusNodes[2], // Location
              decoration: const InputDecoration(
                labelText: 'Location *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Location is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agent',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            AgentDropdown(
              selectedAgentId: _selectedAgentId,
              labelText: 'Agent *',
              hintText: 'Select an agent',
              onChanged: (value) {
                setState(() {
                  _selectedAgentId = value;
                });
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please select an agent';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contract',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contractController,
              focusNode: _manualFocusNodes[3], // Contract Details
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Contract Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Contract File Upload Section
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickContractFiles(),
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Add Contract Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldColor,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),

            // Display selected contract files
            if (_contractFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_contractFiles.length, (index) {
                final file = _contractFiles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[600]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.name,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeContractFile(index),
                        icon: const Icon(Icons.close, color: Colors.red),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlightsSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flights Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _formNavigation.createInputField(
              label: 'Flight Cost',
              controller: _flightCostController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Flight Files Upload Section
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickFlightFiles(),
                    icon: const Icon(Icons.flight),
                    label: const Text('Add Flight Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldColor,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),

            // Display selected flight files
            if (_flightFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_flightFiles.length, (index) {
                final file = _flightFiles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[600]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.name,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeFlightFile(index),
                        icon: const Icon(Icons.close, color: Colors.red),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHotelSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hotel/Apartment Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hotelAddressController,
              focusNode: _manualFocusNodes[4], // Hotel/Apartment Address
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Hotel/Apartment Address *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Hotel/Apartment address is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hotelCostController,
              focusNode: _manualFocusNodes[5], // Hotel Cost
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hotel Cost',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPocketMoneySection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pocket Money',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _hasPocketMoney,
                  onChanged: (value) {
                    setState(() {
                      _hasPocketMoney = value ?? false;
                      if (!_hasPocketMoney) {
                        _pocketMoneyCostController.clear();
                      }
                    });
                  },
                ),
                const Text(
                  'Has Pocket Money',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            if (_hasPocketMoney) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _pocketMoneyCostController,
                focusNode: _manualFocusNodes[6], // Pocket Money Cost
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pocket Money Cost',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              focusNode: _manualFocusNodes[7], // Notes
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final args = ModalRoute.of(context)?.settings.arguments;
    final isEditing = args is OnStay || widget.stay != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.grey),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _loading ? null : _saveStay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(isEditing ? 'Update Stay' : 'Save Stay'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // If end date is before start date, clear it
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveStay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      // Get editing state before async operations
      final args = ModalRoute.of(context)?.settings.arguments;
      final editingStay = args is OnStay ? args : widget.stay;

      // Generate stay ID for file organization
      final stayId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload files if any
      List<String> allFileUrls = [];

      if (_contractFiles.isNotEmpty || _flightFiles.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 16),
                  Text('Uploading files...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        // Upload contract files
        if (_contractFiles.isNotEmpty) {
          final contractUrls = await FileUploadService.uploadEventFiles(
            files: _contractFiles,
            eventId: stayId,
            eventType: 'on_stay_contract',
          );
          allFileUrls.addAll(contractUrls);
        }

        // Upload flight files
        if (_flightFiles.isNotEmpty) {
          final flightUrls = await FileUploadService.uploadEventFiles(
            files: _flightFiles,
            eventId: stayId,
            eventType: 'on_stay_flight',
          );
          allFileUrls.addAll(flightUrls);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }

      // Map new form fields to existing OnStay model structure
      final data = {
        'location_name': _locationController.text.trim(),
        'stay_type': 'On Stay', // Fixed type for on stay
        'address': _hotelAddressController.text.trim().isEmpty
            ? null
            : _hotelAddressController.text.trim(),
        'check_in_date': _startDate?.toIso8601String().split('T')[0],
        'check_out_date': _endDate?.toIso8601String().split('T')[0],
        'check_in_time': null,
        'check_out_time': null,
        'cost': _hotelCostController.text.trim().isEmpty
            ? 0.0
            : double.tryParse(_hotelCostController.text) ?? 0.0,
        'currency': 'USD',
        'contact_name': _agencyNameController.text.trim().isEmpty
            ? null
            : _agencyNameController.text.trim(),
        'contact_phone': null,
        'contact_email': null,
        'agent_id': _selectedAgentId,
        'status': 'confirmed',
        'payment_status': 'unpaid',
        'notes': _buildNotesString(),
        'files': allFileUrls.isNotEmpty ? allFileUrls : null,
      };

      OnStay? result;
      if (editingStay != null) {
        // Update existing stay
        result = await OnStayService.update(editingStay.id, data);
      } else {
        // Create new stay
        result = await OnStayService.create(data);
      }

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(editingStay != null
                  ? 'Stay updated successfully!'
                  : 'Stay created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        throw Exception('Failed to save stay');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving stay: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _buildNotesString() {
    List<String> notesParts = [];

    if (_agencyNameController.text.trim().isNotEmpty) {
      notesParts.add('Agency: ${_agencyNameController.text.trim()}');
    }

    if (_agencyAddressController.text.trim().isNotEmpty) {
      notesParts.add('Agency Address: ${_agencyAddressController.text.trim()}');
    }

    if (_contractController.text.trim().isNotEmpty) {
      notesParts.add('Contract: ${_contractController.text.trim()}');
    }

    if (_flightCostController.text.trim().isNotEmpty) {
      notesParts.add('Flight Cost: ${_flightCostController.text.trim()}');
    }

    if (_hasPocketMoney && _pocketMoneyCostController.text.trim().isNotEmpty) {
      notesParts.add('Pocket Money: ${_pocketMoneyCostController.text.trim()}');
    }

    if (_notesController.text.trim().isNotEmpty) {
      notesParts.add('Additional Notes: ${_notesController.text.trim()}');
    }

    return notesParts.join('\n\n');
  }

  // File handling methods
  Future<void> _pickContractFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _contractFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking contract files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFlightFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _flightFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking flight files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeContractFile(int index) {
    setState(() {
      _contractFiles.removeAt(index);
    });
  }

  void _removeFlightFile(int index) {
    setState(() {
      _flightFiles.removeAt(index);
    });
  }
}
