import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/models/meeting.dart';
import 'package:new_flutter/services/meetings_service.dart';
import 'package:intl/intl.dart';

class NewMeetingPage extends StatefulWidget {
  const NewMeetingPage({super.key});

  @override
  State<NewMeetingPage> createState() => _NewMeetingPageState();
}

class _NewMeetingPageState extends State<NewMeetingPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  String _selectedStatus = 'scheduled';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedAgentId;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingId;

  final List<String> _statusOptions = [
    'scheduled',
    'canceled',
    'declined',
    'postponed',
    'completed'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null) {
        if (args is Map<String, dynamic>) {
          _loadInitialData(args);
        } else if (args is String) {
          _loadMeeting(args);
        } else if (args is Meeting) {
          // Handle Meeting object directly
          _loadMeetingFromObject(args);
        }
      }
    });
  }

  void _loadInitialData(Map<String, dynamic> data) {
    setState(() {
      _subjectController.text = data['subject'] ?? '';
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
      _notesController.text = data['notes'] ?? '';
      _selectedAgentId = data['bookingAgent'];
    });
  }

  void _loadMeetingFromObject(Meeting meeting) {
    setState(() {
      _isEditing = true;
      _editingId = meeting.id;
      _subjectController.text = meeting.type ?? ''; // Use type as subject
      _locationController.text = meeting.location ?? '';
      _selectedDate = DateTime.tryParse(meeting.date) ?? DateTime.now();
      _notesController.text = meeting.notes ?? '';
      _selectedStatus = meeting.status ?? 'scheduled';
      _selectedAgentId = meeting.bookingAgent;

      // Parse time strings
      if (meeting.time != null && meeting.time!.isNotEmpty) {
        final timeParts = meeting.time!.split(':');
        _startTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
      if (meeting.endTime != null && meeting.endTime!.isNotEmpty) {
        final timeParts = meeting.endTime!.split(':');
        _endTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 0,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
    });
  }

  Future<void> _loadMeeting(String id) async {
    setState(() {
      _isLoading = true;
      _isEditing = true;
      _editingId = id;
    });

    try {
      final meeting = await MeetingsService.getMeetingById(id);
      if (meeting != null) {
        _loadMeetingFromObject(meeting);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading meeting: $e'),
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
    _subjectController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleOcrDataExtracted(Map<String, dynamic> data) {
    debugPrint('🏢 OCR data extracted for meeting: $data');
    debugPrint('🏢 Start time in data: ${data['startTime']}');
    debugPrint('🏢 End time in data: ${data['endTime']}');
    debugPrint('🏢 Time in data: ${data['time']}');

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

      // Map client name to subject
      if (data['clientName'] != null) {
        _subjectController.text = data['clientName'];
      }

      // Map meeting type/subject
      if (data['meetingType'] != null) {
        _subjectController.text = data['meetingType'];
      } else if (data['subject'] != null) {
        _subjectController.text = data['subject'];
      } else if (data['type'] != null) {
        _subjectController.text = data['type'];
      }

      // Map location
      if (data['location'] != null) {
        _locationController.text = data['location'];
      }

      // Map start time
      if (data['time'] != null || data['startTime'] != null) {
        final timeStr = (data['startTime'] ?? data['time']).toString();
        debugPrint('🏢 Parsing start time: $timeStr');
        try {
          if (timeStr.contains('AM') || timeStr.contains('PM')) {
            // 12-hour format parsing
            final cleanTime =
                timeStr.replaceAll(RegExp(r'[^\d:APM\s]'), '').trim();
            debugPrint('🏢 Cleaned start time: $cleanTime');
            final timePart =
                cleanTime.split(' ')[0]; // Get time part before AM/PM
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
              debugPrint(
                  '🏢 Parsed start time: ${_startTime?.format(context)}');
            }
          } else {
            // 24-hour format parsing
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              _startTime = TimeOfDay(hour: hour, minute: minute);
              debugPrint(
                  '🏢 Parsed start time (24h): ${_startTime?.format(context)}');
            }
          }
        } catch (e) {
          debugPrint('❌ Could not parse start time: $timeStr - Error: $e');
        }
      }

      // Map end time
      if (data['endTime'] != null) {
        final timeStr = data['endTime'].toString();
        debugPrint('🏢 Parsing end time: $timeStr');
        try {
          if (timeStr.contains('AM') || timeStr.contains('PM')) {
            // 12-hour format parsing
            final cleanTime =
                timeStr.replaceAll(RegExp(r'[^\d:APM\s]'), '').trim();
            debugPrint('🏢 Cleaned end time: $cleanTime');
            final timePart =
                cleanTime.split(' ')[0]; // Get time part before AM/PM
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
              _endTime = TimeOfDay(hour: hour, minute: minute);
              debugPrint('🏢 Parsed end time: ${_endTime?.format(context)}');
            }
          } else {
            // 24-hour format parsing
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              _endTime = TimeOfDay(hour: hour, minute: minute);
              debugPrint(
                  '🏢 Parsed end time (24h): ${_endTime?.format(context)}');
            }
          }
        } catch (e) {
          debugPrint('❌ Could not parse end time: $timeStr - Error: $e');
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
        final agentInfo = 'Industry Contact: ${data['bookingAgent']}';
        _notesController.text =
            currentNotes.isEmpty ? agentInfo : '$currentNotes\n$agentInfo';
      } else {
        // Set default agent ID for ogbhai
        _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj';

        final currentNotes = _notesController.text;
        final agentInfo = 'Industry Contact: ogbhai(uzibhaikiagencykoishak)';
        _notesController.text =
            currentNotes.isEmpty ? agentInfo : '$currentNotes\n$agentInfo';
      }

      // Map agenda/requirements to notes
      if (data['agenda'] != null) {
        final currentNotes = _notesController.text;
        final agenda = 'Agenda: ${data['agenda']}';
        _notesController.text =
            currentNotes.isEmpty ? agenda : '$currentNotes\n$agenda';
      }

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

    debugPrint('🏢 Meeting form populated with OCR data');
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

    debugPrint('🏢 NewMeetingPage._handleSubmit() - Starting submit...');
    setState(() {
      _isLoading = true;
    });

    try {
      final meeting = Meeting(
        id: _editingId,
        clientName:
            _subjectController.text, // Use subject as clientName for storage
        type: _subjectController.text, // Store subject as type
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        time: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        location: _locationController.text,
        bookingAgent: _selectedAgentId,
        notes: _notesController.text,
        status: _selectedStatus,
      );

      debugPrint(
          '🏢 NewMeetingPage._handleSubmit() - Meeting data: ${meeting.toJson()}');

      if (_isEditing && _editingId != null) {
        debugPrint(
            '🏢 NewMeetingPage._handleSubmit() - Updating meeting with ID: $_editingId');
        await MeetingsService.updateMeeting(_editingId!, meeting.toJson());
      } else {
        debugPrint('🏢 NewMeetingPage._handleSubmit() - Creating new meeting');
        await MeetingsService.createMeeting(meeting.toJson());
      }

      debugPrint(
          '🏢 NewMeetingPage._handleSubmit() - Meeting saved successfully');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ NewMeetingPage._handleSubmit() - Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving meeting: $e'),
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
        currentPage: '/new-meeting',
        title: _isEditing ? 'Edit Meeting' : 'New Meeting',
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AppLayout(
      currentPage: '/new-meeting',
      title: _isEditing ? 'Edit Meeting' : 'New Meeting',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new meetings (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  onAutoSubmit: () {
                    debugPrint('Auto-submitting meeting form after OCR...');
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
                    label: 'Subject',
                    controller: _subjectController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter subject';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _formNavigation.createInputField(
                    label: 'Location',
                    controller: _locationController,
                  ),
                  const SizedBox(height: 16),
                  AgentDropdown(
                    selectedAgentId: _selectedAgentId,
                    labelText: 'Industry Contact',
                    hintText: 'Select an industry contact',
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
                  _buildTimeFields(),
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
                          : (_isEditing ? 'Update Meeting' : 'Create Meeting'),
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

  Widget _buildTimeFields() {
    return Row(
      children: [
        Expanded(
          child: Column(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        _startTime != null
                            ? _formatTime(_startTime)
                            : 'Select time',
                        style: TextStyle(
                          color: _startTime != null
                              ? Colors.white
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'End Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectTime(false),
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
                      const Icon(Icons.access_time, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        _endTime != null
                            ? _formatTime(_endTime)
                            : 'Select time',
                        style: TextStyle(
                          color:
                              _endTime != null ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                _selectedStatus = value ?? 'scheduled';
              });
            },
          ),
        ),
      ],
    );
  }
}
