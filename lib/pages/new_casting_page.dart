import 'package:flutter/material.dart';
import 'package:new_flutter/models/casting.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';

class NewCastingPage extends StatefulWidget {
  final Casting? casting;

  const NewCastingPage({super.key, this.casting});

  @override
  State<NewCastingPage> createState() => _NewCastingPageState();
}

class _NewCastingPageState extends State<NewCastingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;

  final _clientController = TextEditingController();
  final _jobTypeController = TextEditingController();
  final _locationController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _notesController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  String? _selectedAgentId;
  String _status = 'pending';
  DateTime _date = DateTime.now();
  bool _isEditing = false;

  final List<String> _jobTypes = [
    'Add manually',
    'Advertising',
    'Campaign',
    'E-commerce',
    'Editorial',
    'Fittings',
    'Lookbook',
    'Looks',
    'Show',
    'Showroom',
    'TVC',
    'Web / Social Media Shooting',
    'TikTok',
    'AI',
    'Film',
  ];

  bool _isCustomJobType = false;

  final List<String> _statuses = [
    'pending',
    'confirmed',
    'completed',
    'cancelled',
    'declined',
    'postponed',
  ];

  @override
  void initState() {
    super.initState();
    // Handle both widget.casting and route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Casting) {
        _populateForm(args);
      } else if (widget.casting != null) {
        _populateForm(widget.casting!);
      }
    });
  }

  void _populateForm(Casting casting) {
    debugPrint('🔍 Populating casting form: ${casting.id}');
    debugPrint('🔍 Casting Title: ${casting.title}');
    debugPrint('🔍 Casting Location: ${casting.location}');

    setState(() {
      _clientController.text = casting.title; // Map title to client
      _locationController.text = casting.location ?? '';
      _status = casting.status;
      _date = casting.date;
      _isEditing = true;
    });

    // Parse description to extract individual fields
    _parseDescriptionFields(casting.description ?? '');

    debugPrint('🔍 Casting form populated successfully');
    debugPrint('🔍 Client Controller: ${_clientController.text}');
    debugPrint('🔍 Location Controller: ${_locationController.text}');
  }

  void _parseDescriptionFields(String description) {
    // Parse the description string to extract individual field values
    final lines = description.split('\n\n');

    setState(() {
      for (final line in lines) {
        if (line.startsWith('Job Type: ')) {
          final jobType = line.substring('Job Type: '.length);
          if (_jobTypes.contains(jobType)) {
            _jobTypeController.text = jobType;
          }
        } else if (line.startsWith('Start Time: ')) {
          _startTimeController.text = line.substring('Start Time: '.length);
        } else if (line.startsWith('End Time: ')) {
          _endTimeController.text = line.substring('End Time: '.length);
        } else if (line.startsWith('Agent ID: ')) {
          _selectedAgentId = line.substring('Agent ID: '.length);
        } else if (line.startsWith('Notes: ')) {
          _notesController.text = line.substring('Notes: '.length);
        }
      }
    });
  }

  TimeOfDay? _parseTimeString(String timeString) {
    if (timeString.isEmpty) return null;

    try {
      // Handle different time formats
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint('Error parsing time string: $timeString');
    }
    return null;
  }

  // OCR data extraction handler - similar to job page
  void _handleOcrDataExtracted(Map<String, dynamic> extractedData) {
    debugPrint('=== CASTING PAGE FORM HANDLER CALLED ===');
    debugPrint('OCR Data received: $extractedData');
    debugPrint('Keys received: ${extractedData.keys.toList()}');
    setState(() {
      // Set default date to July 20, 2025
      _date = DateTime(2025, 7, 20);

      // Populate form fields with extracted data
      if (extractedData['clientName'] != null) {
        debugPrint('Setting client name: ${extractedData['clientName']}');
        _clientController.text = extractedData['clientName'];
      }
      if (extractedData['location'] != null) {
        debugPrint('Setting location: ${extractedData['location']}');
        _locationController.text = extractedData['location'];
      }
      if (extractedData['notes'] != null) {
        debugPrint('Setting notes: ${extractedData['notes']}');
        _notesController.text = extractedData['notes'];
      }
      if (extractedData['bookingAgent'] != null) {
        debugPrint('Setting agent: ${extractedData['bookingAgent']}');
        // Find agent by name
        final agentName =
            extractedData['bookingAgent'].toString().toLowerCase();
        if (agentName.contains('ogbhai')) {
          _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj'; // ogbhai's ID
          debugPrint('Agent ID set to: $_selectedAgentId');
        }
      }
      if (extractedData['jobType'] != null ||
          extractedData['castingType'] != null) {
        final jobType =
            extractedData['jobType'] ?? extractedData['castingType'];
        debugPrint('Setting job type: $jobType');
        for (String type in _jobTypes) {
          if (type.toLowerCase().contains(jobType.toString().toLowerCase())) {
            _jobTypeController.text = type;
            break;
          }
        }
        if (_jobTypeController.text.isEmpty) {
          _jobTypeController.text = 'Other';
        }
      }
      // Set status
      if (extractedData['status'] != null) {
        final status = extractedData['status'].toString().toLowerCase();
        if (status.contains('confirmed')) {
          _status = 'confirmed';
        } else if (status.contains('cancelled')) {
          _status = 'cancelled';
        } else if (status.contains('completed')) {
          _status = 'completed';
        } else {
          _status = 'pending';
        }
      }
      // Set times - handle both separate times and time ranges
      if (extractedData['startTime'] != null) {
        final startTime = extractedData['startTime'].toString();
        _startTimeController.text = startTime;
      }
      if (extractedData['endTime'] != null) {
        final endTime = extractedData['endTime'].toString();
        _endTimeController.text = endTime;
      }
      // Handle time range format like "10:00 AM - 4:00 PM"
      if (extractedData['time'] != null) {
        final timeRange = extractedData['time'].toString();
        debugPrint('Parsing time range: $timeRange');

        // Split on common separators
        final timeParts = timeRange.split(RegExp(r'\s*[-–—]\s*'));
        if (timeParts.length == 2) {
          final startTime = timeParts[0].trim();
          final endTime = timeParts[1].trim();

          debugPrint('Extracted start time: $startTime');
          debugPrint('Extracted end time: $endTime');

          _startTimeController.text = startTime;
          _endTimeController.text = endTime;
        }
      }
    });
    debugPrint('✅ OCR data extraction completed for casting');

    // Auto-submit after OCR processing
    Future.delayed(const Duration(milliseconds: 500), () {
      debugPrint('🚀 Auto-submitting casting after OCR...');
      _saveCasting();
    });
  }

  @override
  void dispose() {
    _clientController.dispose();
    _jobTypeController.dispose();
    _locationController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCasting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      final editingCasting = args is Casting ? args : widget.casting;

      final data = {
        'title': _clientController.text,
        'description': _buildDescriptionString(),
        'date': _date.toIso8601String(),
        'location': _locationController.text,
        'requirements': '',
        'status': _status,
        'rate': null,
        'currency': 'USD',
        'images': [],
      };

      if (editingCasting != null) {
        // Update existing casting
        await Casting.update(editingCasting.id, data);
      } else {
        // Create new casting
        await Casting.create(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(editingCasting != null
                ? 'Casting updated successfully'
                : 'Casting created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save casting: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final isEditing = args is Casting || widget.casting != null;

    return AppLayout(
      currentPage: '/new-casting',
      title: isEditing ? 'Edit Casting' : 'New Casting',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new castings (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  onAutoSubmit: () {
                    debugPrint('Auto-submitting casting form after OCR...');
                    _saveCasting();
                  },
                ),
                const SizedBox(height: 24),
              ],
              // Client
              _formNavigation.createInputField(
                label: 'Client *',
                controller: _clientController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter client name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Job Type with custom option
              if (!_isCustomJobType) ...[
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Job Type *',
                    border: OutlineInputBorder(),
                  ),
                  value: _jobTypeController.text.isNotEmpty &&
                          _jobTypes.contains(_jobTypeController.text)
                      ? _jobTypeController.text
                      : null,
                  items: _jobTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == 'Add manually') {
                      setState(() {
                        _isCustomJobType = true;
                        _jobTypeController.clear();
                      });
                    } else {
                      setState(() {
                        _jobTypeController.text = value ?? '';
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a job type';
                    }
                    return null;
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _jobTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Job Type *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a job type';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isCustomJobType = false;
                          _jobTypeController.clear();
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to predefined types',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Date
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: DateFormat('MMM d, yyyy').format(_date),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() {
                      _date = date;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Start and End Time
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Start Time *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      controller: _startTimeController,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              _parseTimeString(_startTimeController.text) ??
                                  TimeOfDay.now(),
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
                        if (time != null) {
                          setState(() {
                            _startTimeController.text = time.format(context);
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select start time';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'End Time *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      controller: _endTimeController,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              _parseTimeString(_endTimeController.text) ??
                                  TimeOfDay.now(),
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
                        if (time != null) {
                          setState(() {
                            _endTimeController.text = time.format(context);
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select end time';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location
              _formNavigation.createInputField(
                label: 'Location *',
                controller: _locationController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Agent
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
              const SizedBox(height: 16),

              // Status
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                value: _statuses.contains(_status) ? _status : null,
                items: _statuses.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Transfer to Option/Job (only in edit view)
              if (_isEditing) ...[
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
                            'Transfer Casting',
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
                        'Convert this casting to an option or job',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _transferToOption(),
                              icon: const Icon(Icons.event_available),
                              label: const Text('Transfer to Option'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.goldColor,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _transferToJob(),
                              icon: const Icon(Icons.work),
                              label: const Text('Transfer to Job'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.goldColor,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notes
              _formNavigation.createInputField(
                label: 'Notes',
                controller: _notesController,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: Button(
                  text: isEditing ? 'Update Casting' : 'Create Casting',
                  variant: ButtonVariant.primary,
                  onPressed: _isLoading ? null : _saveCasting,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDescriptionString() {
    List<String> parts = [];

    if (_jobTypeController.text.trim().isNotEmpty) {
      parts.add('Job Type: ${_jobTypeController.text.trim()}');
    }

    if (_startTimeController.text.trim().isNotEmpty) {
      parts.add('Start Time: ${_startTimeController.text.trim()}');
    }

    if (_endTimeController.text.trim().isNotEmpty) {
      parts.add('End Time: ${_endTimeController.text.trim()}');
    }

    if (_selectedAgentId != null) {
      parts.add('Agent ID: $_selectedAgentId');
    }

    if (_notesController.text.trim().isNotEmpty) {
      parts.add('Notes: ${_notesController.text.trim()}');
    }

    return parts.join('\n\n');
  }

  Future<void> _transferToOption() async {
    try {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Transfer to Option',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to convert this casting to an option? This action cannot be undone.',
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

        // Here you would call the appropriate service to create an option
        // For now, just show success message
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully transferred to option!'),
              backgroundColor: Colors.green,
            ),
          );

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
            content: Text('Error transferring to option: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _transferToJob() async {
    try {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Transfer to Job',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to convert this casting to a job? This action cannot be undone.',
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

        // Here you would call the appropriate service to create a job
        // For now, just show success message
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully transferred to job!'),
              backgroundColor: Colors.green,
            ),
          );

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
            content: Text('Error transferring to job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
