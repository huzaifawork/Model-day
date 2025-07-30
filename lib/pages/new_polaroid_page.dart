import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/models/polaroid.dart';
import 'package:new_flutter/services/polaroids_service.dart';
import 'package:intl/intl.dart';

class NewPolaroidPage extends StatefulWidget {
  const NewPolaroidPage({super.key});

  @override
  State<NewPolaroidPage> createState() => _NewPolaroidPageState();
}

class _NewPolaroidPageState extends State<NewPolaroidPage> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _costController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  String _selectedPolaroidType = 'Free';
  String _selectedStatus = 'pending';
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _callTime;
  String? _selectedAgentId;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingId;

  final List<String> _polaroidTypes = ['Free', 'Paid'];
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

  final List<String> _statusOptions = [
    'pending',
    'confirmed',
    'completed',
    'canceled',
    'declined',
    'postponed'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint(
          '📸 NewPolaroidPage initState - Arguments type: ${args.runtimeType}');
      debugPrint('📸 NewPolaroidPage initState - Arguments value: $args');
      if (args != null) {
        if (args is Map<String, dynamic>) {
          debugPrint(
              '📸 NewPolaroidPage initState - Loading initial data from Map');
          _loadInitialData(args);
        } else if (args is String) {
          debugPrint(
              '📸 NewPolaroidPage initState - Loading polaroid with ID: $args');
          _loadPolaroid(args);
        } else {
          debugPrint(
              '📸 NewPolaroidPage initState - Unknown argument type: ${args.runtimeType}');
        }
      } else {
        debugPrint(
            '📸 NewPolaroidPage initState - No arguments, creating new polaroid');
      }
    });
  }

  void _loadInitialData(Map<String, dynamic> data) {
    setState(() {
      _selectedDate = DateTime.tryParse(data['date'] ?? '') ?? DateTime.now();
      if (data['callTime'] != null && data['callTime'].isNotEmpty) {
        final timeParts = data['callTime'].split(':');
        _callTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
      _locationController.text = data['location'] ?? '';
      _notesController.text = data['notes'] ?? '';
      _selectedAgentId = data['bookingAgent'];
      _selectedPolaroidType = data['polaroidType'] ?? 'Free';
      if (data['cost'] != null) {
        _costController.text = data['cost'].toString();
      }
    });
  }

  Future<void> _loadPolaroid(String id) async {
    debugPrint(
        '📸 NewPolaroidPage._loadPolaroid() - Loading polaroid with ID: $id');
    setState(() {
      _isLoading = true;
      _isEditing = true;
      _editingId = id;
    });

    try {
      final polaroid = await PolaroidsService.getPolaroidById(id);
      debugPrint(
          '📸 NewPolaroidPage._loadPolaroid() - Retrieved polaroid: ${polaroid?.clientName}');
      if (polaroid != null) {
        debugPrint(
            '📸 NewPolaroidPage._loadPolaroid() - Populating form with polaroid data');
        debugPrint(
            '📸 Polaroid data: type=${polaroid.type}, location=${polaroid.location}, date=${polaroid.date}');
        setState(() {
          _selectedPolaroidType = polaroid.type ?? 'Free';
          _locationController.text = polaroid.location ?? '';
          _selectedDate = DateTime.tryParse(polaroid.date) ?? DateTime.now();
          _notesController.text = polaroid.notes ?? '';
          _selectedStatus = polaroid.status ?? 'pending';
          _selectedAgentId = polaroid.bookingAgent;

          // Parse call time
          if (polaroid.time != null && polaroid.time!.isNotEmpty) {
            final timeParts = polaroid.time!.split(':');
            _callTime = TimeOfDay(
              hour: int.tryParse(timeParts[0]) ?? 0,
              minute: int.tryParse(timeParts[1]) ?? 0,
            );
            debugPrint('📸 Parsed call time: ${_callTime?.format(context)}');
          }

          // Handle cost for paid polaroids
          if (polaroid.rate != null) {
            _costController.text = polaroid.rate.toString();
            debugPrint('📸 Set cost: ${_costController.text}');
          }

          // Handle currency for paid polaroids
          if (polaroid.currency != null &&
              _currencies.contains(polaroid.currency)) {
            _selectedCurrency = polaroid.currency!;
            debugPrint('📸 Set currency: $_selectedCurrency');
          }
        });
        debugPrint(
            '📸 NewPolaroidPage._loadPolaroid() - Form populated successfully');
      } else {
        debugPrint('📸 NewPolaroidPage._loadPolaroid() - Polaroid not found');
      }
    } catch (e) {
      debugPrint('📸 Error loading polaroid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading polaroid: $e'),
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
    _locationController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _handleOcrDataExtracted(Map<String, dynamic> data) {
    debugPrint('📸 OCR data extracted for polaroid: $data');

    setState(() {
      // Set default date to July 28, 2025 if no date extracted
      if (data['date'] != null) {
        try {
          _selectedDate = DateTime.parse(data['date']);
        } catch (e) {
          debugPrint('Could not parse date: ${data['date']}');
          _selectedDate = DateTime(2025, 7, 28);
        }
      } else {
        _selectedDate = DateTime(2025, 7, 28);
      }

      // Map location
      if (data['location'] != null) {
        _locationController.text = data['location'];
      }

      // Map time to call time
      if (data['time'] != null) {
        try {
          final timeStr = data['time'].toString();
          if (timeStr.contains('AM') || timeStr.contains('PM')) {
            // 12-hour format parsing
            final cleanTime = timeStr.replaceAll(RegExp(r'[^\d:]'), '');
            final parts = cleanTime.split(':');
            if (parts.length >= 2) {
              int hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              if (timeStr.contains('PM') && hour != 12) hour += 12;
              if (timeStr.contains('AM') && hour == 12) hour = 0;
              _callTime = TimeOfDay(hour: hour, minute: minute);
            }
          } else {
            // 24-hour format parsing
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              _callTime = TimeOfDay(hour: hour, minute: minute);
            }
          }
        } catch (e) {
          debugPrint('Could not parse time: ${data['time']}');
        }
      }

      // Map polaroid type and cost
      if (data['rate'] != null ||
          data['dayRate'] != null ||
          data['cost'] != null) {
        final costValue = data['cost'] ?? data['rate'] ?? data['dayRate'];
        _costController.text = costValue.toString();
        _selectedPolaroidType = 'Paid'; // Switch to paid if cost is provided
      } else if (data['polaroidType'] != null) {
        final type = data['polaroidType'].toString().toLowerCase();
        if (type.contains('paid') || type.contains('commercial')) {
          _selectedPolaroidType = 'Paid';
        } else if (type.contains('free') || type.contains('tfp')) {
          _selectedPolaroidType = 'Free';
        }
      }

      // Map status
      if (data['status'] != null) {
        final status = data['status'].toString().toLowerCase();
        if (_statusOptions.contains(status)) {
          _selectedStatus = status;
        }
      }

      // Map agent - try to find matching agent ID
      if (data['bookingAgent'] != null) {
        final agentName = data['bookingAgent'].toString().toLowerCase();
        // Check if the agent name contains "ogbhai" - map to the known agent ID
        if (agentName.contains('ogbhai')) {
          _selectedAgentId =
              'sUAOiTx4b9dzTlSkIIOj'; // Known agent ID for ogbhai
        }

        // Also add to notes for reference
        final currentNotes = _notesController.text;
        final agentInfo = 'Agent: ${data['bookingAgent']}';
        _notesController.text =
            currentNotes.isEmpty ? agentInfo : '$currentNotes\n$agentInfo';
      } else {
        // Set default agent ID for ogbhai
        _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj';

        final currentNotes = _notesController.text;
        final agentInfo = 'Agent: ogbhai(uzibhaikiagencykoishak)';
        _notesController.text =
            currentNotes.isEmpty ? agentInfo : '$currentNotes\n$agentInfo';
      }

      // Map requirements to notes
      if (data['requirements'] != null) {
        final currentNotes = _notesController.text;
        final requirements = 'Requirements: ${data['requirements']}';
        _notesController.text = currentNotes.isEmpty
            ? requirements
            : '$currentNotes\n$requirements';
      }

      // Add description/notes from OCR if available
      if (data['notes'] != null) {
        final currentNotes = _notesController.text;
        final ocrNotes = data['notes'].toString();
        _notesController.text =
            currentNotes.isEmpty ? ocrNotes : '$currentNotes\n$ocrNotes';
      }
    });

    debugPrint('📸 Polaroid form populated with OCR data');
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

  Future<void> _selectCallTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _callTime ?? TimeOfDay.now(),
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
        _callTime = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final polaroid = Polaroid(
        id: _editingId,
        clientName: '', // Not required for polaroids
        type: _selectedPolaroidType,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        time: _formatTime(_callTime),
        location: _locationController.text,
        bookingAgent: _selectedAgentId,
        notes: _notesController.text,
        status: _selectedStatus,
        rate: _selectedPolaroidType == 'Paid' && _costController.text.isNotEmpty
            ? double.tryParse(_costController.text)
            : null,
        currency: _selectedPolaroidType == 'Paid' ? _selectedCurrency : null,
      );

      debugPrint(
          '📸 NewPolaroidPage._handleSubmit() - Saving polaroid with data: ${polaroid.toJson()}');
      debugPrint('📸 Is editing: $_isEditing, Editing ID: $_editingId');

      if (_isEditing && _editingId != null) {
        debugPrint('📸 Updating existing polaroid with ID: $_editingId');
        await PolaroidsService.updatePolaroid(_editingId!, polaroid.toJson());
      } else {
        debugPrint('📸 Creating new polaroid');
        await PolaroidsService.createPolaroid(polaroid.toJson());
      }

      if (mounted) {
        debugPrint('📸 Polaroid saved successfully, returning to list');
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving polaroid session: $e'),
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
        currentPage: '/new-polaroid',
        title: _isEditing ? 'Edit Polaroid Session' : 'New Polaroid Session',
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AppLayout(
      currentPage: '/new-polaroid',
      title: _isEditing ? 'Edit Polaroid Session' : 'New Polaroid Session',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new polaroids (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  onAutoSubmit: () {
                    debugPrint('Auto-submitting polaroid form after OCR...');
                    _handleSubmit();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information
              _buildSectionCard(
                'Basic Information',
                [
                  _buildPolaroidTypeField(),
                  const SizedBox(height: 16),
                  _formNavigation.createInputField(
                    label: 'Location',
                    controller: _locationController,
                  ),
                  const SizedBox(height: 16),
                  AgentDropdown(
                    selectedAgentId: _selectedAgentId,
                    labelText: 'Agent / Contact',
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

              // Scheduling
              _buildSectionCard(
                'Scheduling',
                [
                  _buildDateField(),
                  const SizedBox(height: 16),
                  _buildCallTimeField(),
                  const SizedBox(height: 16),
                  _buildStatusField(),
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
                          : (_isEditing ? 'Update Session' : 'Create Session'),
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

  Widget _buildPolaroidTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Polaroids Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2E2E2E)),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedPolaroidType,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  items: _polaroidTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPolaroidType = value ?? 'Free';
                      if (_selectedPolaroidType == 'Free') {
                        _costController.clear();
                      }
                    });
                  },
                ),
              ),
            ),
            if (_selectedPolaroidType == 'Paid') ...[
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _formNavigation.createInputField(
                  label: 'Cost',
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_selectedPolaroidType == 'Paid' &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter cost';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedCurrency,
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
              ),
            ],
          ],
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

  Widget _buildCallTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Call Time',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectCallTime,
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
                  _callTime != null
                      ? _formatTime(_callTime)
                      : 'Select call time',
                  style: TextStyle(
                    color: _callTime != null ? Colors.white : Colors.white70,
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
            value: _statusOptions.contains(_selectedStatus)
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
}
