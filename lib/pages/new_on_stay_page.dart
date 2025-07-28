import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/models/on_stay.dart';
import 'package:new_flutter/services/on_stay_service.dart';
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
    });

    debugPrint('🏨 Form populated successfully');
    debugPrint('🏨 Location Controller: ${_locationController.text}');
    debugPrint('🏨 Hotel Address Controller: ${_hotelAddressController.text}');
    debugPrint('🏨 Agency Name Controller: ${_agencyNameController.text}');
    debugPrint('🏨 Hotel Cost Controller: ${_hotelCostController.text}');
    debugPrint('🏨 Start Date: $_startDate');
    debugPrint('🏨 End Date: $_endDate');
  }

  // OCR data extraction handler - similar to job page
  void _handleOcrDataExtracted(Map<String, dynamic> extractedData) {
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
          _startDate = DateTime(2025, 7, 21);
          debugPrint(
              'Failed to parse check-in date, using default: $_startDate');
        }
      } else {
        _startDate = DateTime(2025, 7, 21);
      }

      if (extractedData['checkOutDate'] != null) {
        try {
          _endDate = DateTime.parse(extractedData['checkOutDate']);
          debugPrint('Setting check-out date from OCR: $_endDate');
        } catch (e) {
          _endDate = DateTime(2025, 7, 23);
          debugPrint(
              'Failed to parse check-out date, using default: $_endDate');
        }
      } else {
        _endDate = DateTime(2025, 7, 23);
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
      // Extract and set agent
      if (extractedData['bookingAgent'] != null ||
          extractedData['agent'] != null) {
        final agentName =
            extractedData['bookingAgent'] ?? extractedData['agent'];
        debugPrint('Setting agent: $agentName');

        // Simple agent matching based on known agents
        final agentNameLower = agentName.toString().toLowerCase();
        if (agentNameLower.contains('ogbhai')) {
          _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj'; // ogbhai's ID
          debugPrint('Agent ID set to: $_selectedAgentId (ogbhai)');
        } else if (agentNameLower.contains('sarah') ||
            agentNameLower.contains('johnson')) {
          _selectedAgentId = 'jy07nJzMq9ZvahfeJBAa'; // Sarah Johnson's ID
          debugPrint('Agent ID set to: $_selectedAgentId (Sarah Johnson)');
        }
      }
    });
    debugPrint('✅ OCR data extraction completed for on stay');

    // Auto-submit after OCR processing with longer delay to ensure all fields are populated
    Future.delayed(const Duration(milliseconds: 1500), () {
      debugPrint('🚀 Auto-submitting on stay after OCR...');
      _saveStay();
    });
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
                    onAutoSubmit: () {
                      debugPrint('Auto-submitting on stay form after OCR...');
                      _saveStay();
                    },
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
            _formNavigation.createInputField(
              label: 'Agency Name *',
              controller: _agencyNameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Agency name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _formNavigation.createInputField(
              label: 'Agency Address *',
              controller: _agencyAddressController,
              maxLines: 2,
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
            _formNavigation.createInputField(
              label: 'Location *',
              controller: _locationController,
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
            _formNavigation.createInputField(
              label: 'Contract Details',
              controller: _contractController,
              maxLines: 3,
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
            _formNavigation.createInputField(
              label: 'Hotel/Apartment Address *',
              controller: _hotelAddressController,
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Hotel/Apartment address is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _formNavigation.createInputField(
              label: 'Hotel Cost',
              controller: _hotelCostController,
              keyboardType: TextInputType.number,
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
              _formNavigation.createInputField(
                label: 'Pocket Money Cost',
                controller: _pocketMoneyCostController,
                keyboardType: TextInputType.number,
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
            _formNavigation.createInputField(
              label: 'Notes',
              controller: _notesController,
              maxLines: 4,
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

    if (_selectedAgentId != null) {
      notesParts.add('Agent ID: $_selectedAgentId');
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
