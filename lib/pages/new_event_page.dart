import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_flutter/models/event.dart';
import 'package:new_flutter/services/events_service.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/ui/input.dart' as ui;
import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/safe_dropdown.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:new_flutter/services/file_upload_service.dart';
import 'package:new_flutter/widgets/file_preview_widget.dart';
import 'package:intl/intl.dart';

class NewEventPage extends StatefulWidget {
  final EventType eventType;
  final Event? existingEvent;

  const NewEventPage({
    super.key,
    required this.eventType,
    this.existingEvent,
  });

  @override
  State<NewEventPage> createState() => _NewEventPageState();
}

class _NewEventPageState extends State<NewEventPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _clientNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _dayRateController = TextEditingController();
  final _usageRateController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _subjectController = TextEditingController();
  final _eventNameController = TextEditingController();
  final _photographerController = TextEditingController();
  final _agencyNameController = TextEditingController();
  final _agencyAddressController = TextEditingController();
  final _hotelAddressController = TextEditingController();
  final _flightCostController = TextEditingController();
  final _hotelCostController = TextEditingController();
  final _pocketMoneyController = TextEditingController();
  final _industryContactController = TextEditingController();

  // New missing field controllers
  final _agencyFeeController = TextEditingController();
  final _extraHoursController = TextEditingController();
  final _taxController = TextEditingController();
  final _callTimeController = TextEditingController();
  final _contractController = TextEditingController();
  final _transferToJobController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  // Form State
  DateTime _selectedDate = DateTime(2025, 7, 14);
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _selectedCurrency = 'USD';
  EventStatus _selectedStatus = EventStatus.scheduled;
  PaymentStatus _selectedPaymentStatus = PaymentStatus.unpaid;
  OptionStatus _selectedOptionStatus = OptionStatus.pending;
  String? _selectedAgentId;
  final List<PlatformFile> _selectedFiles = [];
  Map<String, dynamic>?
      _uploadedFileData; // Store uploaded file data for preview
  bool _isLoading = false;
  bool _isDateRange = false;
  bool _isPaid = false;
  bool _hasPocketMoney = false;
  TimeOfDay? _callTime;
  String? _error;

  // Job Types for casting/test
  String? _selectedJobType;
  String? _selectedOptionType;
  String _selectedTestType = 'Free';
  String _selectedPolaroidType = 'Free';
  bool _isCustomJobType = false;
  bool _isCustomOptionType = false;
  bool _isEditMode = false; // Will be set to true when editing existing option

  // Currencies
  final List<String> _currencies = [
    'USD',
    'EUR',
    'PLN',
    'ILS',
    'JPY',
    'KRW',
    'GBP',
    'CNY',
    'AUD'
  ];

  // Job Types
  final List<String> _jobTypes = [
    'Add manually',
    'Advertising',
    'Campaign',
    'Commercial',
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
    'Film'
  ];

  @override
  void initState() {
    super.initState();

    debugPrint('🔍 NewEventPage.initState() - Event type: ${widget.eventType}');
    debugPrint(
        '🔍 NewEventPage.initState() - Existing event: ${widget.existingEvent?.id}');

    // Check if we're in edit mode
    if (widget.existingEvent != null) {
      debugPrint('✅ NewEventPage.initState() - Edit mode detected');
      _isEditMode = true;
      _populateFieldsFromEvent(widget.existingEvent!);
      // Force a rebuild after populating fields
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            debugPrint('🔄 Forcing UI rebuild after field population');
          });
        }
      });
    } else {
      debugPrint('ℹ️ NewEventPage.initState() - Create mode');
      // Check for arguments passed via route
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map<String, dynamic>) {
          debugPrint(
              '🔍 NewEventPage.initState() - Found route arguments: $args');
          // Check for existingEvent (from calendar edit)
          if (args['existingEvent'] != null && args['existingEvent'] is Event) {
            debugPrint(
                '✅ NewEventPage.initState() - Edit mode from route arguments (existingEvent)');
            _isEditMode = true;
            _populateFieldsFromEvent(args['existingEvent'] as Event);
            setState(() {});
          }
          // Also check for event (legacy support)
          else if (args['event'] != null && args['event'] is Event) {
            debugPrint(
                '✅ NewEventPage.initState() - Edit mode from route arguments (event)');
            _isEditMode = true;
            _populateFieldsFromEvent(args['event'] as Event);
            setState(() {});
          }
        }
      });
    }

    // Ensure initial values are valid
    if (!_currencies.contains(_selectedCurrency)) {
      _selectedCurrency = _currencies.first;
    }
  }

  void _populateFieldsFromEvent(Event event) {
    debugPrint(
        '🔍 _populateFieldsFromEvent() - Populating fields for event: ${event.id}');
    debugPrint(
        '🔍 _populateFieldsFromEvent() - Client name: ${event.clientName}');
    debugPrint('🔍 _populateFieldsFromEvent() - Location: ${event.location}');
    debugPrint('🔍 _populateFieldsFromEvent() - Day rate: ${event.dayRate}');
    debugPrint(
        '🔍 _populateFieldsFromEvent() - Additional data: ${event.additionalData}');

    setState(() {
      // Populate basic fields
      if (event.clientName != null) {
        _clientNameController.text = event.clientName!;
        debugPrint('✅ Set client name: ${event.clientName}');
      }
      if (event.location != null) {
        _locationController.text = event.location!;
        debugPrint('✅ Set location: ${event.location}');
      }
      if (event.notes != null) {
        _notesController.text = event.notes!;
        debugPrint('✅ Set notes: ${event.notes}');
      }
      if (event.dayRate != null) {
        _dayRateController.text = event.dayRate.toString();
        debugPrint('✅ Set day rate: ${event.dayRate}');
      }
      if (event.usageRate != null) {
        _usageRateController.text = event.usageRate.toString();
        debugPrint('✅ Set usage rate: ${event.usageRate}');
      }

      // Set dates and times
      if (event.date != null) {
        _selectedDate = event.date!;
      }
      if (event.endDate != null) {
        _endDate = event.endDate!;
        _isDateRange = true;
      }
      if (event.startTime != null && event.startTime!.isNotEmpty) {
        final timeParts = event.startTime!.split(':');
        if (timeParts.length == 2) {
          _startTime = TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0,
          );
        }
      }
      if (event.endTime != null && event.endTime!.isNotEmpty) {
        final timeParts = event.endTime!.split(':');
        if (timeParts.length == 2) {
          _endTime = TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0,
          );
        }
      }

      // Set other fields
      if (event.currency != null) {
        _selectedCurrency = event.currency!;
      }
      if (event.status != null) {
        _selectedStatus = event.status!;
      }
      if (event.paymentStatus != null) {
        _selectedPaymentStatus = event.paymentStatus!;
      }
      if (event.optionStatus != null) {
        _selectedOptionStatus = event.optionStatus!;
      }
      if (event.agentId != null) {
        _selectedAgentId = event.agentId!;
      }
    });

    // Populate additional data based on event type
    if (event.additionalData != null) {
      final data = event.additionalData!;

      switch (event.type) {
        case EventType.option:
        case EventType.directOption:
          if (data['option_type'] != null) {
            if (_jobTypes.contains(data['option_type'])) {
              _selectedOptionType = data['option_type'];
            } else {
              _isCustomOptionType = true;
              _customTypeController.text = data['option_type'];
            }
          }
          if (data['agency_fee'] != null) {
            _agencyFeeController.text = data['agency_fee'].toString();
          }
          break;

        case EventType.job:
        case EventType.directBooking:
          if (data['job_type'] != null) {
            if (_jobTypes.contains(data['job_type'])) {
              _selectedJobType = data['job_type'];
            } else {
              _isCustomJobType = true;
              _customTypeController.text = data['job_type'];
            }
          }
          if (data['agency_fee'] != null) {
            _agencyFeeController.text = data['agency_fee'].toString();
          }
          if (data['extra_hours'] != null) {
            _extraHoursController.text = data['extra_hours'].toString();
          }
          if (data['tax_percentage'] != null) {
            _taxController.text = data['tax_percentage'].toString();
          }
          break;

        case EventType.test:
          if (data['photographer_name'] != null) {
            _photographerController.text = data['photographer_name'];
          }
          if (data['test_type'] != null) {
            _selectedTestType = data['test_type'];
          }
          if (data['is_paid'] != null) {
            _isPaid = data['is_paid'];
          }
          break;

        case EventType.polaroids:
          if (data['polaroid_type'] != null) {
            _selectedPolaroidType = data['polaroid_type'];
          }
          if (data['is_paid'] != null) {
            _isPaid = data['is_paid'];
          }
          break;

        case EventType.meeting:
          if (data['subject'] != null) {
            _subjectController.text = data['subject'];
          }
          if (data['industry_contact'] != null) {
            _industryContactController.text = data['industry_contact'];
          }
          break;

        case EventType.onStay:
          if (data['agency_name'] != null) {
            _agencyNameController.text = data['agency_name'];
          }
          if (data['agency_address'] != null) {
            _agencyAddressController.text = data['agency_address'];
          }
          if (data['hotel_address'] != null) {
            _hotelAddressController.text = data['hotel_address'];
          }
          if (data['flight_cost'] != null) {
            _flightCostController.text = data['flight_cost'].toString();
          }
          if (data['hotel_cost'] != null) {
            _hotelCostController.text = data['hotel_cost'].toString();
          }
          if (data['has_pocket_money'] != null) {
            _hasPocketMoney = data['has_pocket_money'];
          }
          if (data['pocket_money_cost'] != null) {
            _pocketMoneyController.text = data['pocket_money_cost'].toString();
          }
          if (data['contract'] != null) {
            _contractController.text = data['contract'];
          }
          break;

        case EventType.other:
          if (data['event_name'] != null) {
            _eventNameController.text = data['event_name'];
          }
          break;

        case EventType.casting:
          if (data['job_type'] != null) {
            if (_jobTypes.contains(data['job_type'])) {
              _selectedJobType = data['job_type'];
            } else {
              _isCustomJobType = true;
              _customTypeController.text = data['job_type'];
            }
          }
          break;
      }
    }

    // Load existing file data if available
    if (event.files != null) {
      _uploadedFileData = event.files;
      debugPrint('✅ Loaded file data from event.files');
    } else if (event.additionalData != null &&
        event.additionalData!.containsKey('file_data')) {
      _uploadedFileData = event.additionalData!['file_data'];
      debugPrint('✅ Loaded file data from event.additionalData');
    }

    debugPrint('🔍 Event fields populated successfully');
    debugPrint('🔍 Client Name Controller: ${_clientNameController.text}');
    debugPrint('🔍 Location Controller: ${_locationController.text}');
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _dayRateController.dispose();
    _usageRateController.dispose();
    _customTypeController.dispose();
    _subjectController.dispose();
    _eventNameController.dispose();
    _photographerController.dispose();
    _agencyNameController.dispose();
    _agencyAddressController.dispose();
    _hotelAddressController.dispose();
    _flightCostController.dispose();
    _hotelCostController.dispose();
    _pocketMoneyController.dispose();
    _industryContactController.dispose();
    _agencyFeeController.dispose();
    _extraHoursController.dispose();
    _taxController.dispose();
    _callTimeController.dispose();
    _contractController.dispose();
    _transferToJobController.dispose();
    _formNavigation.dispose();
    super.dispose();
  }

  void _handleOcrDataExtracted(Map<String, dynamic> extractedData) {
    debugPrint('=== NEW EVENT PAGE FORM HANDLER CALLED ===');
    debugPrint('OCR Data received: $extractedData');
    setState(() {
      // Populate form fields with extracted data
      if (extractedData['clientName'] != null) {
        debugPrint('Setting client name: ${extractedData['clientName']}');
        _clientNameController.text = extractedData['clientName'];
      }
      if (extractedData['location'] != null) {
        debugPrint('Setting location: ${extractedData['location']}');
        _locationController.text = extractedData['location'];
      }
      if (extractedData['notes'] != null) {
        debugPrint('Setting notes: ${extractedData['notes']}');
        _notesController.text = extractedData['notes'];
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
            if (dateStr.contains('july')) {
              _selectedDate = DateTime(2025, 7, 15);
              debugPrint('Set July date: $_selectedDate');
            } else if (dateStr.contains('march')) {
              _selectedDate = DateTime(2024, 3, 15);
              debugPrint('Set March date: $_selectedDate');
            }
          } catch (e2) {
            debugPrint('Error parsing date format: $e2');
          }
        }
      }
      if (extractedData['dayRate'] != null) {
        debugPrint('Setting day rate: ${extractedData['dayRate']}');
        _dayRateController.text = extractedData['dayRate'].toString();
      }
      if (extractedData['usageRate'] != null) {
        debugPrint('Setting usage rate: ${extractedData['usageRate']}');
        _usageRateController.text = extractedData['usageRate'].toString();
      }
      if (extractedData['bookingAgent'] != null) {
        debugPrint('Setting agent: ${extractedData['bookingAgent']}');
        final extractedAgent =
            extractedData['bookingAgent'].toString().toLowerCase();

        // Handle OCR typos and variations of "ogbhai"
        if (extractedAgent.contains('ogbhai') ||
            extractedAgent.contains('ogbhal') ||
            extractedAgent.contains('ogbha') ||
            extractedAgent.startsWith('ogb')) {
          debugPrint('✅ Recognized ogbhai agent (with OCR variations)');
          _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj'; // Use the actual agent ID
          debugPrint('Agent ID set to: $_selectedAgentId');
        } else {
          debugPrint('⚠️ Unknown agent name, setting default');
          _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj'; // Default to ogbhai
          debugPrint('Agent ID set to default: $_selectedAgentId');
        }
      } else {
        // Set default agent if none extracted
        debugPrint('No agent found in OCR data, setting default agent ID');
        _selectedAgentId = 'sUAOiTx4b9dzTlSkIIOj';
        debugPrint('Default agent ID set to: $_selectedAgentId');
      }

      // Set option type from extracted data or default (only if not manually set)
      if (extractedData['optionType'] != null && !_isCustomOptionType) {
        final extractedType = extractedData['optionType'].toString();
        debugPrint('Setting option type from extracted data: $extractedType');

        // Check if it's a predefined type (excluding "Add manually")
        final predefinedTypes =
            _jobTypes.where((type) => type != 'Add manually').toList();
        if (predefinedTypes.contains(extractedType)) {
          debugPrint('Found predefined option type: $extractedType');
          _selectedOptionType = extractedType;
          _isCustomOptionType = false;
        } else {
          debugPrint(
              'Custom option type detected: $extractedType - switching to Add manually mode');
          _selectedOptionType = 'Add manually';
          _isCustomOptionType = true;
          _customTypeController.text = extractedType;
        }
      } else if ((_selectedOptionType == null ||
              _selectedOptionType!.isEmpty) &&
          !_isCustomOptionType) {
        debugPrint('Setting default option type to Campaign');
        _selectedOptionType = 'Campaign';
        _isCustomOptionType = false;
      }
      debugPrint(
          'Option type set to: $_selectedOptionType, isCustom: $_isCustomOptionType');
      if (_isCustomOptionType) {
        debugPrint('Custom type text: ${_customTypeController.text}');
      }

      // Set option status from extracted data or default
      if (extractedData['status'] != null) {
        final extractedStatus =
            extractedData['status'].toString().toLowerCase();
        debugPrint(
            'Setting option status from extracted data: $extractedStatus');
        if (extractedStatus.contains('pending')) {
          _selectedOptionStatus = OptionStatus.pending;
        } else if (extractedStatus.contains('canceled') ||
            extractedStatus.contains('cancelled')) {
          _selectedOptionStatus = OptionStatus.clientCanceled;
        } else if (extractedStatus.contains('declined')) {
          _selectedOptionStatus = OptionStatus.declined;
        } else if (extractedStatus.contains('postponed')) {
          _selectedOptionStatus = OptionStatus.postponed;
        } else {
          _selectedOptionStatus = OptionStatus.pending; // Default fallback
        }
      } else {
        debugPrint('Setting default option status to pending');
        _selectedOptionStatus = OptionStatus.pending;
      }
      debugPrint('Option status set to: $_selectedOptionStatus');

      // Handle currency from OCR data
      if (extractedData['currency'] != null) {
        debugPrint('Setting currency: ${extractedData['currency']}');
        _selectedCurrency = extractedData['currency'];
      }

      // Handle agency fee from OCR data
      if (extractedData['agencyFee'] != null) {
        debugPrint('Setting agency fee: ${extractedData['agencyFee']}');
        _agencyFeeController.text = extractedData['agencyFee'].toString();
      } else if (_agencyFeeController.text.isEmpty) {
        debugPrint('Setting default agency fee to 20%');
        _agencyFeeController.text = '20';
      }

      // Handle time from OCR data
      if (extractedData['time'] != null) {
        debugPrint('Setting time: ${extractedData['time']}');
        final timeStr = extractedData['time'].toString();
        _parseAndSetTime(timeStr);
      }

      // Populate event-type specific fields based on current event type
      _populateEventSpecificFields(extractedData);

      // Debug: Final agent ID check
      debugPrint('🎯 FINAL CHECK - _selectedAgentId: $_selectedAgentId');
    });

    // Force a UI update after a short delay to ensure dropdowns refresh
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          // Force rebuild to update dropdowns, especially AgentDropdown
          debugPrint('🔄 Forcing UI rebuild - Agent ID: $_selectedAgentId');
        });
      }
    });

    // Additional delay to ensure AgentDropdown specifically updates
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          debugPrint(
              '🔄 Second UI rebuild for AgentDropdown - Agent ID: $_selectedAgentId');
        });
      }
    });

    debugPrint('=== NEW EVENT PAGE FORM UPDATE COMPLETE ===');

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Data extracted successfully! Please review and adjust as needed.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  /// Parse time string and set start/end times
  void _parseAndSetTime(String timeStr) {
    try {
      debugPrint('Parsing time string: $timeStr');

      // Handle formats like "10:00 AM - 8:00 PM" or "9:00 AM - 7:00 PM"
      if (timeStr.contains(' - ')) {
        final parts = timeStr.split(' - ');
        if (parts.length == 2) {
          final startTimeStr = parts[0].trim();
          final endTimeStr = parts[1].trim();

          _startTime = _parseTimeString(startTimeStr);
          _endTime = _parseTimeString(endTimeStr);

          debugPrint('Parsed start time: $_startTime');
          debugPrint('Parsed end time: $_endTime');
        }
      } else {
        // Single time, set as start time
        _startTime = _parseTimeString(timeStr);
        debugPrint('Parsed single time as start time: $_startTime');
      }
    } catch (e) {
      debugPrint('Error parsing time: $e');
    }
  }

  /// Parse individual time string to TimeOfDay
  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final cleanTime = timeStr.trim().toLowerCase();

      // Handle AM/PM format
      bool isPM = cleanTime.contains('pm');
      bool isAM = cleanTime.contains('am');

      // Extract numbers
      final timeOnly = cleanTime.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = timeOnly.split(':');

      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);

        // Convert to 24-hour format
        if (isPM && hour != 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }

        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint('Error parsing individual time: $e');
    }
    return null;
  }

  /// Populate event-type specific fields based on extracted data
  void _populateEventSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating event-specific fields for: ${widget.eventType}');

    switch (widget.eventType) {
      case EventType.option:
      case EventType.directOption:
        _populateOptionSpecificFields(extractedData);
        break;
      case EventType.job:
      case EventType.directBooking:
        _populateJobSpecificFields(extractedData);
        break;
      case EventType.casting:
        _populateCastingSpecificFields(extractedData);
        break;
      case EventType.onStay:
        _populateOnStaySpecificFields(extractedData);
        break;
      case EventType.test:
        _populateTestSpecificFields(extractedData);
        break;
      case EventType.polaroids:
        _populatePolaroidSpecificFields(extractedData);
        break;
      case EventType.meeting:
        _populateMeetingSpecificFields(extractedData);
        break;
      case EventType.other:
        _populateOtherSpecificFields(extractedData);
        break;
    }
  }

  /// Populate Option-specific fields
  void _populateOptionSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating Option-specific fields');

    // Set default call time if not set
    if (_callTime == null) {
      _callTime = const TimeOfDay(hour: 9, minute: 0); // 9:00 AM default
      debugPrint('Set default call time: 9:00 AM');
    }
  }

  /// Populate Job-specific fields
  void _populateJobSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating Job-specific fields');

    // Set job type from option type if available
    if (extractedData['optionType'] != null && _selectedJobType == null) {
      final extractedType = extractedData['optionType'].toString();

      // Check if it's a predefined type (excluding "Add manually")
      final predefinedTypes =
          _jobTypes.where((type) => type != 'Add manually').toList();
      if (predefinedTypes.contains(extractedType)) {
        debugPrint('Found predefined job type: $extractedType');
        _selectedJobType = extractedType;
        _isCustomJobType = false;
      } else {
        debugPrint(
            'Custom job type detected: $extractedType - switching to Add manually mode');
        _selectedJobType = 'Add manually';
        _isCustomJobType = true;
        _customTypeController.text = extractedType;
      }
    }

    // Set default extra hours
    if (_extraHoursController.text.isEmpty) {
      _extraHoursController.text = '0';
      debugPrint('Set default extra hours: 0');
    }

    // Set default tax percentage
    if (_taxController.text.isEmpty) {
      _taxController.text = '10';
      debugPrint('Set default tax: 10%');
    }

    // Set default call time
    if (_callTime == null) {
      _callTime = const TimeOfDay(hour: 8, minute: 30); // 8:30 AM for jobs
      debugPrint('Set default call time: 8:30 AM');
    }
  }

  /// Populate Casting-specific fields
  void _populateCastingSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating Casting-specific fields');
    // Add casting-specific field population logic here
  }

  /// Populate OnStay-specific fields
  void _populateOnStaySpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating OnStay-specific fields');
    // Add on-stay-specific field population logic here
  }

  /// Populate Test-specific fields
  void _populateTestSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating Test-specific fields');
    // Add test-specific field population logic here
  }

  /// Populate Polaroid-specific fields
  void _populatePolaroidSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating Polaroid-specific fields');
    // Add polaroid-specific field population logic here
  }

  /// Populate Meeting-specific fields
  void _populateMeetingSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating Meeting-specific fields');
    // Add meeting-specific field population logic here
  }

  /// Populate Other-specific fields
  void _populateOtherSpecificFields(Map<String, dynamic> extractedData) {
    debugPrint('Populating Other-specific fields');

    // Map event name from various possible fields
    if (extractedData['eventName'] != null) {
      _eventNameController.text = extractedData['eventName'];
      debugPrint(
          'Set event name from eventName: ${extractedData['eventName']}');
    } else if (extractedData['title'] != null) {
      _eventNameController.text = extractedData['title'];
      debugPrint('Set event name from title: ${extractedData['title']}');
    } else if (extractedData['subject'] != null) {
      _eventNameController.text = extractedData['subject'];
      debugPrint('Set event name from subject: ${extractedData['subject']}');
    } else if (extractedData['name'] != null) {
      _eventNameController.text = extractedData['name'];
      debugPrint('Set event name from name: ${extractedData['name']}');
    } else if (extractedData['clientName'] != null) {
      // Fallback to client name if no specific event name found
      _eventNameController.text = extractedData['clientName'];
      debugPrint(
          'Set event name from clientName: ${extractedData['clientName']}');
    }

    // Map description to notes if available
    if (extractedData['description'] != null) {
      final currentNotes = _notesController.text;
      final description = 'Description: ${extractedData['description']}';
      _notesController.text =
          currentNotes.isEmpty ? description : '$currentNotes\n$description';
      debugPrint('Added description to notes: ${extractedData['description']}');
    }

    // Map event type/category to notes if available
    if (extractedData['eventType'] != null ||
        extractedData['category'] != null) {
      final eventType = extractedData['eventType'] ?? extractedData['category'];
      final currentNotes = _notesController.text;
      final typeInfo = 'Event Type: $eventType';
      _notesController.text =
          currentNotes.isEmpty ? typeInfo : '$currentNotes\n$typeInfo';
      debugPrint('Added event type to notes: $eventType');
    }

    // Map organizer information to notes if available
    if (extractedData['organizer'] != null) {
      final currentNotes = _notesController.text;
      final organizerInfo = 'Organizer: ${extractedData['organizer']}';
      _notesController.text = currentNotes.isEmpty
          ? organizerInfo
          : '$currentNotes\n$organizerInfo';
      debugPrint('Added organizer to notes: ${extractedData['organizer']}');
    }

    // Map contact information to notes if available
    if (extractedData['email'] != null || extractedData['phone'] != null) {
      final currentNotes = _notesController.text;
      final contactInfo = <String>[];
      if (extractedData['email'] != null) {
        contactInfo.add('Email: ${extractedData['email']}');
      }
      if (extractedData['phone'] != null) {
        contactInfo.add('Phone: ${extractedData['phone']}');
      }
      final contact = contactInfo.join('\n');
      _notesController.text =
          currentNotes.isEmpty ? contact : '$currentNotes\n$contact';
      debugPrint('Added contact info to notes: $contact');
    }

    debugPrint('Other-specific fields populated successfully');
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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

  /// Build file preview card with theme-aligned styling
  Widget _buildFilePreviewCard(PlatformFile file, int index, bool isUploaded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded
              ? AppTheme.goldColor.withValues(alpha: 0.3)
              : Colors.grey[600]!.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // File type icon with themed background
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getFileTypeColor(file.extension).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getFileTypeColor(file.extension).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              _getFileTypeIcon(file.extension),
              color: _getFileTypeColor(file.extension),
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // File information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      FileUploadService.getFileSize(file.size),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getFileTypeColor(file.extension)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (file.extension ?? 'FILE').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getFileTypeColor(file.extension),
                        ),
                      ),
                    ),
                    if (isUploaded) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.goldColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'UPLOADED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.goldColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action button
          if (!isUploaded) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeFile(index),
              icon: const Icon(Icons.close, size: 20),
              color: Colors.red[400],
              tooltip: 'Remove file',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ],
      ),
    );
  }

  /// Get file type icon based on extension
  IconData _getFileTypeIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Get file type color based on extension
  Color _getFileTypeColor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Colors.pink;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Colors.indigo;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Colors.teal;
      default:
        return AppTheme.goldColor;
    }
  }

  String get _pageTitle {
    final prefix = _isEditMode ? 'Edit' : 'New';
    switch (widget.eventType) {
      case EventType.option:
        return '$prefix Option';
      case EventType.job:
        return '$prefix Job';
      case EventType.directOption:
        return '$prefix Direct Option';
      case EventType.directBooking:
        return '$prefix Direct Booking';
      case EventType.casting:
        return '$prefix Casting';
      case EventType.onStay:
        return '$prefix On Stay';
      case EventType.test:
        return '$prefix Test';
      case EventType.polaroids:
        return '$prefix Polaroids';
      case EventType.meeting:
        return '$prefix Meeting';
      case EventType.other:
        return '$prefix Event';
    }
  }

  Future<void> _transferToJob() async {
    if (widget.eventType != EventType.option) return;

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Transfer to Job'),
          content: const Text(
              'Are you sure you want to transfer this option to a job? This will create a new job entry and update the option status.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Transfer'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isLoading = true);

      // Create job data from current option data
      final jobData = {
        'client_name': _clientNameController.text,
        'job_type': _isCustomOptionType
            ? _customTypeController.text
            : _selectedOptionType,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'end_date': _endDate?.toIso8601String().split('T')[0],
        'start_time': _formatTimeOfDay(_startTime),
        'end_time': _formatTimeOfDay(_endTime),
        'location': _locationController.text,
        'agent_id': _selectedAgentId,
        'day_rate': double.tryParse(_dayRateController.text),
        'usage_rate': double.tryParse(_usageRateController.text),
        'currency': _selectedCurrency,
        'agency_fee': double.tryParse(_agencyFeeController.text),
        'status': 'scheduled',
        'payment_status': 'unpaid',
        'notes': _notesController.text,
        'call_time': _formatTimeOfDay(_callTime),
      };

      // Create the job
      final result = await EventsService().createEvent({
        ...jobData,
        'type': 'job',
      });

      if (result != null) {
        // Update option status to indicate it was transferred
        if (widget.existingEvent?.id != null) {
          await EventsService().updateEvent(widget.existingEvent!.id!, {
            'option_status': 'transferred_to_job',
            'transferred_job_id': result.id,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Option successfully transferred to job!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Error transferring to job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error transferring to job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint('📅 NewEventPage._createEvent() - Starting submit...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Generate event ID for file organization
      final eventId = DateTime.now().millisecondsSinceEpoch.toString();

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
          eventId: eventId,
          eventType: widget.eventType.name,
        );

        if (downloadUrls.length != _selectedFiles.length) {
          throw Exception(
              'Failed to upload all files. Only ${downloadUrls.length}/${_selectedFiles.length} uploaded.');
        }

        fileData = FileUploadService.createFileData(
          downloadUrls: downloadUrls,
          originalFiles: _selectedFiles,
        );

        // Store uploaded file data for preview
        setState(() {
          _uploadedFileData = fileData;
          _selectedFiles
              .clear(); // Clear selected files after successful upload
        });
      }

      final eventData = _buildEventData();

      // Add file data if files were uploaded
      if (fileData != null) {
        eventData['file_data'] = fileData;
      }

      // Add event ID
      eventData['event_id'] = eventId;

      final event = Event(
        id: _isEditMode ? widget.existingEvent?.id : null,
        type: widget.eventType,
        clientName: _clientNameController.text.isNotEmpty
            ? _clientNameController.text
            : null,
        date: _selectedDate,
        endDate: _endDate,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
        agentId: _selectedAgentId,
        dayRate: double.tryParse(_dayRateController.text),
        usageRate: double.tryParse(_usageRateController.text),
        currency: _selectedCurrency,
        status: _selectedStatus,
        paymentStatus: _selectedPaymentStatus,
        optionStatus: _selectedOptionStatus,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        additionalData: eventData,
      );

      debugPrint(
          '📅 NewEventPage._createEvent() - Event data: ${event.toJson()}');

      dynamic result;
      if (_isEditMode && widget.existingEvent?.id != null) {
        debugPrint(
            '📅 NewEventPage._createEvent() - Updating event with ID: ${widget.existingEvent!.id}');

        // Debug existing event data
        debugPrint(
            '🔍 Existing event Google Calendar ID: ${widget.existingEvent!.googleCalendarEventId}');
        debugPrint(
            '🔍 Existing event synced status: ${widget.existingEvent!.syncedToGoogleCalendar}');
        debugPrint(
            '🔍 Existing event last sync: ${widget.existingEvent!.lastSyncDate}');

        // Preserve Google Calendar sync fields when updating
        final eventData = event.toJson();
        if (widget.existingEvent!.googleCalendarEventId != null) {
          eventData['google_calendar_event_id'] =
              widget.existingEvent!.googleCalendarEventId;
          eventData['synced_to_google_calendar'] =
              widget.existingEvent!.syncedToGoogleCalendar;
          eventData['last_sync_date'] =
              widget.existingEvent!.lastSyncDate?.toIso8601String();
          debugPrint(
              '📅 Preserving Google Calendar sync fields - Event ID: ${widget.existingEvent!.googleCalendarEventId}');
        } else {
          debugPrint(
              '❌ No Google Calendar sync fields found in existing event - fetching fresh data');
          // Fetch fresh event data from database to get Google Calendar sync fields
          final freshEvent =
              await EventsService().getEventById(widget.existingEvent!.id!);
          if (freshEvent != null && freshEvent.googleCalendarEventId != null) {
            eventData['google_calendar_event_id'] =
                freshEvent.googleCalendarEventId;
            eventData['synced_to_google_calendar'] =
                freshEvent.syncedToGoogleCalendar;
            eventData['last_sync_date'] =
                freshEvent.lastSyncDate?.toIso8601String();
            debugPrint(
                '📅 Fetched and preserved Google Calendar sync fields - Event ID: ${freshEvent.googleCalendarEventId}');
          }
        }

        result = await EventsService()
            .updateEvent(widget.existingEvent!.id!, eventData);
      } else {
        debugPrint('📅 NewEventPage._createEvent() - Creating new event');
        result = await EventsService().createEvent(event.toJson());
      }

      debugPrint('📅 NewEventPage._createEvent() - Event saved successfully');
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final action = _isEditMode ? 'updated' : 'created';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${widget.eventType.displayName} $action successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        throw Exception('Failed to ${_isEditMode ? 'update' : 'create'} event');
      }
    } catch (e) {
      debugPrint('❌ NewEventPage._createEvent() - Error: $e');
      setState(() {
        final action = _isEditMode ? 'update' : 'create';
        _error =
            'Failed to $action ${widget.eventType.displayName.toLowerCase()}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildEventData() {
    final data = <String, dynamic>{};

    switch (widget.eventType) {
      case EventType.option:
      case EventType.directOption:
        data['option_type'] = _isCustomOptionType
            ? _customTypeController.text
            : _selectedOptionType;
        data['option_status'] =
            _selectedOptionStatus.toString().split('.').last;
        data['agency_fee'] = double.tryParse(_agencyFeeController.text);
        data['call_time'] = _formatTimeOfDay(_callTime);
        break;

      case EventType.job:
      case EventType.directBooking:
        data['job_type'] =
            _isCustomJobType ? _customTypeController.text : _selectedJobType;
        data['agency_fee'] = double.tryParse(_agencyFeeController.text);
        data['extra_hours'] = double.tryParse(_extraHoursController.text);
        data['tax_percentage'] = double.tryParse(_taxController.text);
        data['call_time'] = _formatTimeOfDay(_callTime);
        break;

      case EventType.casting:
        data['job_type'] =
            _isCustomJobType ? _customTypeController.text : _selectedJobType;
        break;

      case EventType.test:
        data['photographer_name'] = _photographerController.text;
        data['test_type'] = _selectedTestType;
        data['is_paid'] = _isPaid;
        data['call_time'] = _formatTimeOfDay(_callTime);
        break;

      case EventType.polaroids:
        data['polaroid_type'] = _selectedPolaroidType;
        data['is_paid'] = _isPaid;
        data['call_time'] = _formatTimeOfDay(_callTime);
        break;

      case EventType.meeting:
        data['subject'] = _subjectController.text;
        data['industry_contact'] = _industryContactController.text;
        break;

      case EventType.onStay:
        data['agency_name'] = _agencyNameController.text;
        data['agency_address'] = _agencyAddressController.text;
        data['hotel_address'] = _hotelAddressController.text;
        data['flight_cost'] = double.tryParse(_flightCostController.text);
        data['hotel_cost'] = double.tryParse(_hotelCostController.text);
        data['has_pocket_money'] = _hasPocketMoney;
        data['pocket_money_cost'] =
            double.tryParse(_pocketMoneyController.text);
        data['contract'] = _contractController.text;
        break;

      case EventType.other:
        data['event_name'] = _eventNameController.text;
        break;
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/new-event',
      title: _pageTitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Text(
                _pageTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isEditMode
                    ? 'Update the details for your ${widget.eventType.displayName.toLowerCase()}'
                    : 'Fill in the details for your ${widget.eventType.displayName.toLowerCase()}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),

              // OCR Widget for Options, Direct Options, and Other Events
              if ((widget.eventType == EventType.option ||
                      widget.eventType == EventType.directOption ||
                      widget.eventType == EventType.other) &&
                  !_isEditMode) ...[
                OcrUploadWidget(
                  onDataExtracted: _handleOcrDataExtracted,
                  onAutoSubmit: () {
                    debugPrint('Auto-submitting event form after OCR...');
                    _createEvent();
                  },
                ),
                const SizedBox(height: 32),
              ],

              // Dynamic form fields based on event type
              ..._buildFormFields(),

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
                  text: _isEditMode
                      ? 'Update ${widget.eventType.displayName}'
                      : 'Create ${widget.eventType.displayName}',
                  variant: ButtonVariant.primary,
                  onPressed: _isLoading ? null : _createEvent,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    final fields = <Widget>[];

    // Common fields for most event types
    if (_needsClientName()) {
      fields.addAll([
        _formNavigation.createInputField(
          controller: _clientNameController,
          placeholder: 'Client name *',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Client name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ]);
    }

    // Event-specific fields
    fields.addAll(_buildEventSpecificFields());

    // Date fields
    fields.addAll(_buildDateFields());

    // Time fields (for most events)
    if (_needsTimeFields()) {
      fields.addAll(_buildTimeFields());
    }

    // Location field
    if (_needsLocation()) {
      fields.addAll([
        const SizedBox(height: 16),
        _formNavigation.createInputField(
          controller: _locationController,
          placeholder: 'Location',
        ),
      ]);
    }

    // Agent field
    if (_needsAgent()) {
      fields.addAll(_buildAgentField());
    }

    // Rate fields
    if (_needsRateFields()) {
      fields.addAll(_buildRateFields());
    }

    // Status fields
    if (_needsStatusFields()) {
      fields.addAll(_buildStatusFields());
    }

    // Files
    fields.addAll(_buildFileUploadSection());

    // Notes
    fields.addAll([
      const SizedBox(height: 24),
      _formNavigation.createInputField(
        controller: _notesController,
        placeholder: 'Notes (optional)',
        maxLines: 3,
      ),
    ]);

    return fields;
  }

  bool _needsClientName() {
    return widget.eventType != EventType.meeting &&
        widget.eventType != EventType.other &&
        widget.eventType != EventType.test &&
        widget.eventType != EventType.polaroids;
  }

  bool _needsTimeFields() {
    return widget.eventType != EventType.onStay &&
        widget.eventType != EventType.option;
  }

  bool _needsLocation() {
    return true; // All events need location
  }

  bool _needsAgent() {
    return widget.eventType != EventType.meeting &&
        widget.eventType != EventType.other;
  }

  bool _needsRateFields() {
    return widget.eventType == EventType.option ||
        widget.eventType == EventType.job ||
        widget.eventType == EventType.directOption ||
        widget.eventType == EventType.directBooking ||
        widget.eventType == EventType.test ||
        widget.eventType == EventType.polaroids;
  }

  bool _needsStatusFields() {
    return widget.eventType == EventType.job ||
        widget.eventType == EventType.directBooking;
  }

  List<Widget> _buildEventSpecificFields() {
    switch (widget.eventType) {
      case EventType.option:
      case EventType.directOption:
        return _buildOptionFields();
      case EventType.job:
      case EventType.directBooking:
        return _buildJobFields();
      case EventType.casting:
        return _buildCastingFields();
      case EventType.onStay:
        return _buildOnStayFields();
      case EventType.test:
        return _buildTestFields();
      case EventType.polaroids:
        return _buildPolaroidFields();
      case EventType.meeting:
        return _buildMeetingFields();
      case EventType.other:
        return _buildOtherFields();
    }
  }

  List<Widget> _buildOptionFields() {
    return [
      SafeDropdown(
        key: ValueKey(
            'option_type_dropdown_$_selectedOptionType'), // Force rebuild
        value: _selectedOptionType,
        items: _jobTypes,
        labelText: 'Option Type',
        hintText: 'Select option type',
        onChanged: (value) {
          debugPrint('Option Type dropdown changed to: $value');
          if (value == 'Add manually') {
            debugPrint('Switching to custom option type mode');
            setState(() {
              _isCustomOptionType = true;
              _selectedOptionType = null;
            });
          } else {
            debugPrint('Setting predefined option type: $value');
            setState(() {
              _isCustomOptionType = false;
              _selectedOptionType = value;
            });
          }
          debugPrint(
              'After change - isCustom: $_isCustomOptionType, selected: $_selectedOptionType');
        },
        validator: (value) {
          if (!_isCustomOptionType && (value == null || value.isEmpty)) {
            return 'Option type is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      if (_isCustomOptionType) ...[
        _formNavigation.createInputField(
          controller: _customTypeController,
          placeholder: 'Enter custom option type',
          validator: (value) {
            if (_isCustomOptionType &&
                (value == null || value.trim().isEmpty)) {
              return 'Option type is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
      // Option Status field
      SafeEnumDropdown<OptionStatus>(
        value: _selectedOptionStatus,
        items: OptionStatus.values,
        labelText: 'Option Status',
        hintText: 'Select option status',
        displayText: (status) => status.displayName,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedOptionStatus = value;
            });
          }
        },
      ),
      const SizedBox(height: 16),
      // Transfer to Job button (only in edit mode for options)
      if (_isEditMode && widget.eventType == EventType.option) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _transferToJob,
            icon: const Icon(Icons.transform),
            label: const Text('Transfer to Job'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      // Agency Fee field
      TextFormField(
        controller: _agencyFeeController,
        decoration: const InputDecoration(
          labelText: 'Agency Fee (%)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
      ),
    ];
  }

  List<Widget> _buildJobFields() {
    return [
      SafeDropdown(
        value: _selectedJobType,
        items: _jobTypes,
        labelText: 'Job Type',
        hintText: 'Select job type',
        onChanged: (value) {
          if (value == 'Add manually') {
            setState(() {
              _isCustomJobType = true;
              _selectedJobType = null;
            });
          } else {
            setState(() {
              _isCustomJobType = false;
              _selectedJobType = value;
            });
          }
        },
        validator: (value) {
          if (!_isCustomJobType && (value == null || value.isEmpty)) {
            return 'Job type is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      if (_isCustomJobType) ...[
        ui.Input(
          controller: _customTypeController,
          placeholder: 'Enter custom job type',
          validator: (value) {
            if (_isCustomJobType && (value == null || value.trim().isEmpty)) {
              return 'Job type is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
      // Financial fields in responsive row
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _agencyFeeController,
              decoration: const InputDecoration(
                labelText: 'Agency Fee (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _extraHoursController,
              decoration: const InputDecoration(
                labelText: 'Extra Hours',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _taxController,
              decoration: const InputDecoration(
                labelText: 'Tax (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Call Time',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              readOnly: true,
              controller: TextEditingController(
                text: _callTime != null ? _formatTimeOfDay(_callTime) : '',
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _callTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _callTime = time;
                  });
                }
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildDateFields() {
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Date *',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              controller: TextEditingController(
                text: DateFormat('MMM d, yyyy').format(_selectedDate),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
              validator: (value) =>
                  value == null || value.isEmpty ? 'Date is required' : null,
            ),
          ),
          if (_isDateRange) ...[
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'End Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(
                  text: _endDate != null
                      ? DateFormat('MMM d, yyyy').format(_endDate!)
                      : '',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        _endDate ?? _selectedDate.add(const Duration(days: 1)),
                    firstDate: _selectedDate,
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
              ),
            ),
          ],
        ],
      ),
      if (widget.eventType == EventType.job ||
          widget.eventType == EventType.directBooking ||
          widget.eventType == EventType.onStay ||
          widget.eventType == EventType.other) ...[
        const SizedBox(height: 16),
        CheckboxListTile(
          title:
              const Text('Date Range', style: TextStyle(color: Colors.white)),
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
        ),
      ],
    ];
  }

  List<Widget> _buildTimeFields() {
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Start Time',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              readOnly: true,
              controller: TextEditingController(
                text: _startTime != null ? _formatTimeOfDay(_startTime) : '',
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _startTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _startTime = time;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'End Time',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              readOnly: true,
              controller: TextEditingController(
                text: _endTime != null ? _formatTimeOfDay(_endTime) : '',
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _endTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _endTime = time;
                  });
                }
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildAgentField() {
    return [
      const SizedBox(height: 16),
      AgentDropdown(
        key: ValueKey(
            'agent_dropdown_$_selectedAgentId'), // Force rebuild when agent changes
        selectedAgentId: _selectedAgentId,
        labelText: 'Agent *',
        hintText: 'Select an agent',
        showAddButton:
            true, // ✅ Enable add button for all event types including options
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
    ];
  }

  List<Widget> _buildRateFields() {
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _dayRateController,
              decoration: const InputDecoration(
                labelText: 'Day Rate',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SafeDropdown(
              value: _selectedCurrency,
              items: _currencies,
              labelText: 'Currency',
              hintText: 'Select currency',
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCurrency = value;
                  });
                }
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _usageRateController,
        decoration: const InputDecoration(
          labelText: 'Usage Rate (optional)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
      ),
    ];
  }

  List<Widget> _buildStatusFields() {
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: SafeEnumDropdown<EventStatus>(
              value: _selectedStatus,
              items: EventStatus.values,
              labelText: 'Status',
              hintText: 'Select status',
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStatus = value;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SafeEnumDropdown<PaymentStatus>(
              value: _selectedPaymentStatus,
              items: PaymentStatus.values,
              labelText: 'Payment Status',
              hintText: 'Select payment status',
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPaymentStatus = value;
                  });
                }
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildFileUploadSection() {
    return [
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              const SizedBox(height: 16),
              const Text(
                'Selected Files (Ready to Upload):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.goldColor,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_selectedFiles.length, (index) {
                final file = _selectedFiles[index];
                return _buildFilePreviewCard(file, index, false);
              }),
            ],

            // Show uploaded files if any
            if (_uploadedFileData != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'Uploaded Files:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.goldColor,
                ),
              ),
              const SizedBox(height: 8),
              FilePreviewWidget(
                fileData: _uploadedFileData,
                showTitle: false,
              ),
            ],

            // Show message when no files
            if (_selectedFiles.isEmpty && _uploadedFileData == null) ...[
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
        ),
      ),
    ];
  }

  List<Widget> _buildCastingFields() {
    return [
      SafeDropdown(
        value: _selectedJobType,
        items: _jobTypes,
        labelText: 'Job Type',
        hintText: 'Select job type',
        onChanged: (value) {
          debugPrint('Job Type dropdown changed to: $value');
          if (value == 'Add manually') {
            debugPrint('Switching to custom job type mode');
            setState(() {
              _isCustomJobType = true;
              _selectedJobType = null;
            });
          } else {
            debugPrint('Setting predefined job type: $value');
            setState(() {
              _isCustomJobType = false;
              _selectedJobType = value;
            });
          }
          debugPrint(
              'After change - isCustomJobType: $_isCustomJobType, selectedJobType: $_selectedJobType');
        },
        validator: (value) {
          if (!_isCustomJobType && (value == null || value.isEmpty)) {
            return 'Job type is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      if (_isCustomJobType) ...[
        _formNavigation.createInputField(
          controller: _customTypeController,
          placeholder: 'Enter custom job type',
          validator: (value) {
            if (_isCustomJobType && (value == null || value.trim().isEmpty)) {
              return 'Job type is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  List<Widget> _buildTestFields() {
    return [
      _formNavigation.createInputField(
        controller: _photographerController,
        placeholder: 'Photographer name *',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Photographer name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: SafeDropdown(
              value: _selectedTestType,
              items: const ['Free', 'Paid'],
              labelText: 'Test Type',
              hintText: 'Select test type',
              onChanged: (value) {
                setState(() {
                  _selectedTestType = value ?? 'Free';
                  _isPaid = value == 'Paid';
                });
              },
            ),
          ),
          if (_isPaid) ...[
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _dayRateController,
                decoration: const InputDecoration(
                  labelText: 'Rate',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ],
      ),
      // Call Time field
      const SizedBox(height: 16),
      TextFormField(
        decoration: const InputDecoration(
          labelText: 'Call Time',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.access_time),
        ),
        readOnly: true,
        controller: TextEditingController(
          text: _callTime != null ? _formatTimeOfDay(_callTime) : '',
        ),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _callTime ?? TimeOfDay.now(),
          );
          if (time != null) {
            setState(() {
              _callTime = time;
            });
          }
        },
      ),
    ];
  }

  List<Widget> _buildPolaroidFields() {
    return [
      Row(
        children: [
          Expanded(
            child: SafeDropdown(
              value: _selectedPolaroidType,
              items: const ['Free', 'Paid'],
              labelText: 'Polaroid Type',
              hintText: 'Select polaroid type',
              onChanged: (value) {
                setState(() {
                  _selectedPolaroidType = value ?? 'Free';
                  _isPaid = value == 'Paid';
                });
              },
            ),
          ),
          if (_isPaid) ...[
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _dayRateController,
                decoration: const InputDecoration(
                  labelText: 'Cost',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ],
      ),
      // Call Time field
      const SizedBox(height: 16),
      TextFormField(
        decoration: const InputDecoration(
          labelText: 'Call Time',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.access_time),
        ),
        readOnly: true,
        controller: TextEditingController(
          text: _callTime != null ? _formatTimeOfDay(_callTime) : '',
        ),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _callTime ?? TimeOfDay.now(),
          );
          if (time != null) {
            setState(() {
              _callTime = time;
            });
          }
        },
      ),
    ];
  }

  List<Widget> _buildMeetingFields() {
    return [
      _formNavigation.createInputField(
        controller: _subjectController,
        placeholder: 'Subject *',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Subject is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _formNavigation.createInputField(
        controller: _industryContactController,
        placeholder: 'Industry contact',
      ),
    ];
  }

  List<Widget> _buildOtherFields() {
    return [
      _formNavigation.createInputField(
        controller: _eventNameController,
        placeholder: 'Event name *',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Event name is required';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildOnStayFields() {
    return [
      _formNavigation.createInputField(
        controller: _agencyNameController,
        placeholder: 'Agency name *',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Agency name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _formNavigation.createInputField(
        controller: _agencyAddressController,
        placeholder: 'Agency address',
      ),
      const SizedBox(height: 16),
      _formNavigation.createInputField(
        controller: _hotelAddressController,
        placeholder: 'Hotel/Apartment address',
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _flightCostController,
              decoration: const InputDecoration(
                labelText: 'Flight cost',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _hotelCostController,
              decoration: const InputDecoration(
                labelText: 'Hotel cost',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _formNavigation.createInputField(
        controller: _contractController,
        placeholder: 'Contract details',
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title:
            const Text('Pocket Money', style: TextStyle(color: Colors.white)),
        value: _hasPocketMoney,
        onChanged: (value) {
          setState(() {
            _hasPocketMoney = value ?? false;
          });
        },
        activeColor: AppTheme.goldColor,
      ),
      if (_hasPocketMoney) ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _pocketMoneyController,
          decoration: const InputDecoration(
            labelText: 'Pocket money cost',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
        ),
      ],
    ];
  }
}
