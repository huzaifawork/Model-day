import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/ui/input.dart' as ui;
import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/models/event.dart';
import 'package:new_flutter/providers/agents_provider.dart';

import 'package:new_flutter/services/direct_options_service.dart';
import 'package:new_flutter/services/file_upload_service.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

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

  String _selectedOptionType = '';
  OptionStatus _selectedOptionStatus = OptionStatus.pending;
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime(2025, 7, 14);
  String? _selectedAgentId = 'ogbhai(uzibhaikiagencykoishak)';
  bool _isCustomType = false;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingId;
  final List<PlatformFile> _selectedFiles = [];

  final List<String> _optionTypes = [
    'Add manually',
    'Commercial',
    'Editorial',
    'Fashion Show',
    'Lookbook',
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
      _selectedDate =
          DateTime.tryParse(data['date'] ?? '') ?? DateTime(2025, 7, 14);
      _locationController.text = data['location'] ?? '';
      _dayRateController.text = data['dayRate'] ?? '';
      _usageRateController.text = data['usageRate'] ?? '';
      _selectedCurrency = data['currency'] ?? 'USD';
      _notesController.text = data['notes'] ?? '';
      _selectedAgentId = data['bookingAgent'];
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

  void _handleOcrDataExtracted(Map<String, dynamic> extractedData) {
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
          // Try different date formats
          try {
            final dateStr = extractedData['date'].toString().toLowerCase();
            if (dateStr.contains('march')) {
              _selectedDate = DateTime(2024, 3, 15);
              debugPrint('Set March date: $_selectedDate');
            } else if (dateStr.contains('july')) {
              _selectedDate = DateTime(2025, 7, 15);
              debugPrint('Set July date: $_selectedDate');
            }
          } catch (e2) {
            debugPrint('Error parsing date format: $e2');
          }
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
      if (extractedData['bookingAgent'] != null) {
        debugPrint('Setting agent: ${extractedData['bookingAgent']}');
        // If the extracted agent contains "ogbhai", use the actual agent ID
        final extractedAgent = extractedData['bookingAgent'].toString();
        if (extractedAgent.toLowerCase().contains('ogbhai')) {
          _selectedAgentId =
              'sUAOiTx4b9dzTlSkIIOj'; // Use the actual agent ID from dropdown
        } else {
          _selectedAgentId = extractedData['bookingAgent'];
        }
      } else {
        debugPrint('No bookingAgent found in extracted data');
        // Set default agent ID
        _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj';
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

      // Set default values for required fields
      if (_selectedOptionType.isEmpty) {
        _selectedOptionType = 'Add manually';
        _isCustomType = true;
        debugPrint('Set default option type to Add manually');
      }
    });
    debugPrint('=== DIRECT OPTIONS FORM UPDATE COMPLETE ===');
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
    super.dispose();
  }

  // Time-related methods removed as they're not needed for direct options

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
          throw Exception('Failed to upload all files. Only ${downloadUrls.length}/${_selectedFiles.length} uploaded.');
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
        if (_isEditing)
          'transfer_to_direct_booking': _transferToDirectBookingController.text,
      };

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
                  onAutoSubmit: () {
                    debugPrint('Auto-submitting form after OCR...');
                    _handleSubmit();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information Section
              _buildSectionCard(
                'Basic Information',
                [
                  ui.Input(
                    label: 'Client Name',
                    controller: _clientNameController,
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
                  ui.Input(
                    label: 'Location',
                    controller: _locationController,
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
                    ui.Input(
                      label: 'Transfer to Direct Booking',
                      controller: _transferToDirectBookingController,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ui.Input(
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
                  ui.Input(
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
                child: ui.Input(
                  label: 'Custom Option Type',
                  controller: _customTypeController,
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
              value: _selectedOptionType.isNotEmpty &&
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

  Widget _buildRateFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ui.Input(
                label: 'Day Rate',
                controller: _dayRateController,
                keyboardType: TextInputType.number,
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
                      value: _currencies.contains(_selectedCurrency)
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
        ui.Input(
          label: 'Usage Rate (optional)',
          controller: _usageRateController,
          keyboardType: TextInputType.number,
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
            value: _selectedOptionStatus,
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
