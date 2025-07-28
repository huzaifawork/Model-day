import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_flutter/models/job.dart';
import 'package:new_flutter/services/jobs_service.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/safe_dropdown.dart';
import 'package:new_flutter/widgets/ui/agent_dropdown.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/widgets/file_preview_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:new_flutter/services/file_upload_service.dart';

class NewJobPage extends StatefulWidget {
  final Job? job; // For editing existing job

  const NewJobPage({super.key, this.job});

  @override
  State<NewJobPage> createState() => _NewJobPageState();
}

class _NewJobPageState extends State<NewJobPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic Information Controllers
  final _clientNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _customJobTypeController = TextEditingController();

  // Financial Controllers
  final _rateController = TextEditingController();
  final _usageController = TextEditingController();
  final _extraHoursController = TextEditingController();
  final _agencyFeeController = TextEditingController();
  final _taxController = TextEditingController();
  final _additionalFeesController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  // Form State
  DateTime _selectedDate = DateTime.now();
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  TimeOfDay? _callTime;
  String _selectedJobType = 'Add manually';
  String _selectedCurrency = 'USD';
  String _selectedStatus = 'Scheduled';
  String _selectedPaymentStatus = 'Unpaid';
  String? _selectedAgentId;
  final List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;
  bool _isCustomType = false;
  bool _isDateRange = false;
  String? _error;

  // Multi-day job support
  final Map<DateTime, TimeOfDay> _dailyCallTimes = {};
  final Map<DateTime, TimeOfDay> _dailyStartTimes = {};
  final Map<DateTime, TimeOfDay> _dailyEndTimes = {};
  bool _separateDailyTimes = false;

  // Job Types
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
    'Film'
  ];

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

  // Status Options
  final List<String> _statusOptions = [
    'Scheduled',
    'In Progress',
    'Completed',
    'Canceled'
  ];

  final List<String> _paymentStatusOptions = [
    'Unpaid',
    'Partially Paid',
    'Paid'
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('🔧 NewJobPage.initState() - job: ${widget.job?.id}');
    if (widget.job != null) {
      debugPrint('📝 Loading job data for editing: ${widget.job!.clientName}');
      _loadJobData();
    } else {
      debugPrint('➕ Creating new job');
      _handlePreselectedDate();
    }
  }

  void _handlePreselectedDate() {
    // Handle preselected date from calendar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('preselectedDate')) {
        final preselectedDate = args['preselectedDate'] as DateTime?;
        if (preselectedDate != null) {
          setState(() {
            _selectedDate = preselectedDate;
          });
          debugPrint('📅 Preselected date set: ${preselectedDate.toString()}');
        }
      }
    });
  }

  void _loadJobData() {
    final job = widget.job!;

    debugPrint('🔍 Loading job data: ${job.id}');
    debugPrint('🔍 Client Name: ${job.clientName}');
    debugPrint('🔍 Job Type: ${job.type}');
    debugPrint('🔍 Location: ${job.location}');
    debugPrint('🔍 File Data: ${job.fileData}');

    setState(() {
      // Load basic information
      _clientNameController.text = job.clientName;
      _locationController.text = job.location;
      _notesController.text = job.notes ?? '';

      // Load job type
      if (_jobTypes.contains(job.type)) {
        _selectedJobType = job.type;
        _isCustomType = false;
      } else {
        _customJobTypeController.text = job.type;
        _isCustomType = true;
        _selectedJobType = '';
      }

      // Load dates and times
      if (job.date.isNotEmpty) {
        _selectedDate = DateTime.parse(job.date);
      }
      if (job.time != null && job.time!.isNotEmpty) {
        final timeParts = job.time!.split(':');
        if (timeParts.length == 2) {
          _startTime = TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0,
          );
        }
      }
      if (job.endTime != null && job.endTime!.isNotEmpty) {
        final timeParts = job.endTime!.split(':');
        if (timeParts.length == 2) {
          _endTime = TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0,
          );
        }
      }

      // Load call time and daily schedule data from additional data
      if (job.fileData != null) {
        final data = job.fileData!;

        // Load call time
        if (data['call_time'] != null &&
            data['call_time'].toString().isNotEmpty) {
          final timeParts = data['call_time'].toString().split(':');
          if (timeParts.length == 2) {
            _callTime = TimeOfDay(
              hour: int.tryParse(timeParts[0]) ?? 0,
              minute: int.tryParse(timeParts[1]) ?? 0,
            );
          }
        }

        // Load multi-day settings
        if (data['is_multi_day'] == true) {
          _isDateRange = true;
        }

        // Load daily schedule data
        if (data['has_daily_schedule'] == true) {
          _separateDailyTimes = true;

          if (data['daily_call_times'] != null) {
            final dailyCallTimes =
                data['daily_call_times'] as Map<String, dynamic>;
            for (final entry in dailyCallTimes.entries) {
              final date = DateTime.parse(entry.key);
              final timeParts = entry.value.toString().split(':');
              if (timeParts.length == 2) {
                _dailyCallTimes[date] = TimeOfDay(
                  hour: int.tryParse(timeParts[0]) ?? 0,
                  minute: int.tryParse(timeParts[1]) ?? 0,
                );
              }
            }
          }

          if (data['daily_start_times'] != null) {
            final dailyStartTimes =
                data['daily_start_times'] as Map<String, dynamic>;
            for (final entry in dailyStartTimes.entries) {
              final date = DateTime.parse(entry.key);
              final timeParts = entry.value.toString().split(':');
              if (timeParts.length == 2) {
                _dailyStartTimes[date] = TimeOfDay(
                  hour: int.tryParse(timeParts[0]) ?? 0,
                  minute: int.tryParse(timeParts[1]) ?? 0,
                );
              }
            }
          }

          if (data['daily_end_times'] != null) {
            final dailyEndTimes =
                data['daily_end_times'] as Map<String, dynamic>;
            for (final entry in dailyEndTimes.entries) {
              final date = DateTime.parse(entry.key);
              final timeParts = entry.value.toString().split(':');
              if (timeParts.length == 2) {
                _dailyEndTimes[date] = TimeOfDay(
                  hour: int.tryParse(timeParts[0]) ?? 0,
                  minute: int.tryParse(timeParts[1]) ?? 0,
                );
              }
            }
          }
        }
      }

      // Load financial information
      _rateController.text = job.rate.toString();
      _extraHoursController.text = job.extraHours?.toString() ?? '';
      _agencyFeeController.text = job.agencyFeePercentage?.toString() ?? '';
      _taxController.text = job.taxPercentage?.toString() ?? '';
      _additionalFeesController.text = job.additionalFees?.toString() ?? '';

      // Load other fields
      _selectedCurrency = job.currency ?? 'USD';
      _selectedStatus = job.status ?? 'Scheduled';
      _selectedPaymentStatus = job.paymentStatus ?? 'Unpaid';
      _selectedAgentId = job.bookingAgent;

      // Load existing files from fileData
      _selectedFiles.clear();
      if (job.fileData != null && job.fileData!.containsKey('files')) {
        final files = job.fileData!['files'] as List?;
        if (files != null) {
          for (final fileInfo in files) {
            if (fileInfo is Map<String, dynamic>) {
              // Create a mock PlatformFile for display purposes
              // Note: This won't have the actual file bytes, but will show the file info
              final mockFile = PlatformFile(
                name: fileInfo['name'] ?? 'Unknown file',
                size: fileInfo['size'] ?? 0,
                bytes: null, // We don't have the original bytes
                path: fileInfo['url'], // Store URL in path for reference
              );
              _selectedFiles.add(mockFile);
            }
          }
          debugPrint('🔍 Loaded ${_selectedFiles.length} existing files');
        }
      }
    });

    debugPrint('🔍 Job data loaded successfully');
    debugPrint('🔍 Client Name Controller: ${_clientNameController.text}');
    debugPrint('🔍 Location Controller: ${_locationController.text}');
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _customJobTypeController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _rateController.dispose();
    _usageController.dispose();
    _extraHoursController.dispose();
    _agencyFeeController.dispose();
    _taxController.dispose();
    _additionalFeesController.dispose();
    _formNavigation.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Duration? _calculateDuration() {
    if (_startTime == null || _endTime == null) return null;

    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

    // Handle overnight duration
    final durationMinutes = endMinutes >= startMinutes
        ? endMinutes - startMinutes
        : (24 * 60) - startMinutes + endMinutes;

    return Duration(minutes: durationMinutes);
  }

  bool _isOvernightDuration() {
    if (_startTime == null || _endTime == null) return false;

    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

    return endMinutes < startMinutes;
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.goldColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.goldColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getFileCategory(String? extension) {
    if (extension == null) return 'Other';

    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'Contract/Agreement';
      case 'doc':
      case 'docx':
        return 'Document';
      case 'xls':
      case 'xlsx':
        return 'Invoice/Schedule';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Image';
      default:
        return 'Other';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Contract/Agreement':
        return Colors.blue[300]!;
      case 'Document':
        return Colors.green[300]!;
      case 'Invoice/Schedule':
        return Colors.orange[300]!;
      case 'Image':
        return Colors.purple[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  double _calculateExtraHours() {
    final extraHours = double.tryParse(_extraHoursController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    return extraHours * (rate * 0.1); // 10% of rate per hour
  }

  double _calculateSubtotal() {
    final rate = double.tryParse(_rateController.text) ?? 0;
    final usage = double.tryParse(_usageController.text) ?? 0;
    final extraHours = _calculateExtraHours();
    final additionalFees = double.tryParse(_additionalFeesController.text) ?? 0;
    return rate + usage + extraHours + additionalFees;
  }

  double _calculateAgencyFee() {
    final subtotal = _calculateSubtotal();
    final agencyFeePercentage = double.tryParse(_agencyFeeController.text) ?? 0;
    return subtotal * (agencyFeePercentage / 100);
  }

  double _calculateTax() {
    final afterAgencyFee = _calculateSubtotal() - _calculateAgencyFee();
    final taxPercentage = double.tryParse(_taxController.text) ?? 0;
    return afterAgencyFee * (taxPercentage / 100);
  }

  double _calculateTotal() {
    final subtotal = _calculateSubtotal();
    final agencyFee = _calculateAgencyFee();
    final tax = _calculateTax();
    return subtotal - agencyFee - tax;
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

  Widget _buildSummaryRow(String label, double amount,
      {bool isTotal = false,
      bool isSubtotal = false,
      bool isDeduction = false}) {
    Color textColor = Colors.white;
    FontWeight fontWeight = FontWeight.normal;
    double fontSize = 14;

    if (isTotal) {
      fontWeight = FontWeight.w600;
      fontSize = 16;
      textColor = AppTheme.goldColor;
    } else if (isSubtotal) {
      fontWeight = FontWeight.w500;
      fontSize = 15;
    } else if (isDeduction) {
      textColor = Colors.red[300]!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: fontWeight,
                fontSize: fontSize,
                color: textColor,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} $_selectedCurrency',
            style: TextStyle(
              fontWeight: fontWeight,
              fontSize: fontSize,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _handleOcrDataExtracted(Map<String, dynamic> extractedData) {
    debugPrint('=== JOB PAGE FORM HANDLER CALLED ===');
    debugPrint('OCR Data received: $extractedData');
    debugPrint('Keys received: ${extractedData.keys.toList()}');
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
        }
      }
      if (extractedData['dayRate'] != null) {
        debugPrint('Setting day rate: ${extractedData['dayRate']}');
        _rateController.text = extractedData['dayRate'].toString();
      }
      if (extractedData['usageRate'] != null) {
        debugPrint('Setting usage rate: ${extractedData['usageRate']}');
        _usageController.text = extractedData['usageRate'].toString();
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
          extractedData['optionType'] != null) {
        final jobType = extractedData['jobType'] ?? extractedData['optionType'];
        debugPrint('Setting job type from extracted data: $jobType');
        if (jobType != null) {
          _selectedJobType = 'Add manually';
          _customJobTypeController.text = jobType.toString();
          debugPrint('Custom job type set to: $jobType');
        }
      }
      if (extractedData['status'] != null) {
        debugPrint(
            'Setting status from extracted data: ${extractedData['status']}');
        final status = extractedData['status'].toString().toLowerCase();
        if (status.contains('confirmed')) {
          _selectedStatus = 'Confirmed';
        } else if (status.contains('postponed')) {
          _selectedStatus = 'Postponed';
        } else if (status.contains('cancelled')) {
          _selectedStatus = 'Cancelled';
        } else {
          _selectedStatus = 'Scheduled';
        }
        debugPrint('Status set to: $_selectedStatus');
      }

      // Handle job-specific fields
      if (extractedData['extraHours'] != null) {
        debugPrint('Setting extra hours: ${extractedData['extraHours']}');
        _extraHoursController.text = extractedData['extraHours'].toString();
      }
      if (extractedData['agencyFee'] != null) {
        debugPrint('Setting agency fee: ${extractedData['agencyFee']}');
        _agencyFeeController.text = extractedData['agencyFee'].toString();
      } else if (_agencyFeeController.text.isEmpty) {
        _agencyFeeController.text = '20';
        debugPrint('Setting default agency fee to 20%');
      }
      if (extractedData['tax'] != null) {
        debugPrint('Setting tax: ${extractedData['tax']}');
        _taxController.text = extractedData['tax'].toString();
      }
      if (extractedData['currency'] != null) {
        debugPrint('Setting currency: ${extractedData['currency']}');
        _selectedCurrency = extractedData['currency'];
      }
      if (extractedData['paymentStatus'] != null) {
        debugPrint('Setting payment status: ${extractedData['paymentStatus']}');
        _selectedPaymentStatus = extractedData['paymentStatus'];
      }
      if (extractedData['requirements'] != null) {
        debugPrint('Setting requirements: ${extractedData['requirements']}');
        // Add requirements to notes if not already there
        if (!_notesController.text.contains(extractedData['requirements'])) {
          if (_notesController.text.isNotEmpty) {
            _notesController.text +=
                '\n\nRequirements:\n${extractedData['requirements']}';
          } else {
            _notesController.text =
                'Requirements:\n${extractedData['requirements']}';
          }
        }
      }
    });
    debugPrint('=== JOB PAGE FORM UPDATE COMPLETE ===');
  }

  Future<void> _createJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Generate job ID for file organization
      final jobId = DateTime.now().millisecondsSinceEpoch.toString();

      // Handle file uploads
      Map<String, dynamic>? fileData;
      if (_selectedFiles.isNotEmpty) {
        // Separate existing files (with URLs) from new files (without URLs)
        final existingFiles = <Map<String, dynamic>>[];
        final newFiles = <PlatformFile>[];

        for (final file in _selectedFiles) {
          if (file.path != null && file.path!.startsWith('http')) {
            // This is an existing file with a URL
            existingFiles.add({
              'name': file.name,
              'size': file.size,
              'url': file.path,
              'extension': file.extension,
            });
          } else {
            // This is a new file that needs to be uploaded
            newFiles.add(file);
          }
        }

        // Upload new files if any
        List<String> newDownloadUrls = [];
        if (newFiles.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(width: 16),
                    Text('Uploading ${newFiles.length} new files...'),
                  ],
                ),
                duration: const Duration(seconds: 30),
              ),
            );
          }

          newDownloadUrls = await FileUploadService.uploadMultipleFiles(
            files: newFiles,
            eventId: jobId,
            eventType: 'job',
          );

          if (newDownloadUrls.length != newFiles.length) {
            throw Exception(
                'Failed to upload all files. Only ${newDownloadUrls.length}/${newFiles.length} uploaded.');
          }
        }

        // Create file data combining existing and new files
        if (existingFiles.isNotEmpty || newDownloadUrls.isNotEmpty) {
          final allFiles = <Map<String, dynamic>>[];

          // Add existing files
          allFiles.addAll(existingFiles);

          // Add new files
          for (int i = 0; i < newFiles.length; i++) {
            final file = newFiles[i];
            allFiles.add({
              'name': file.name,
              'size': file.size,
              'url': newDownloadUrls[i],
              'extension': file.extension,
            });
          }

          fileData = {'files': allFiles};
        }
      }

      final jobData = {
        'client_name': _clientNameController.text,
        'type':
            _isCustomType ? _customJobTypeController.text : _selectedJobType,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'time': _formatTimeOfDay(_startTime),
        'end_time': _formatTimeOfDay(_endTime),
        'location': _locationController.text,
        'booking_agent': _selectedAgentId,
        'rate': double.tryParse(_rateController.text) ?? 0.0,
        'currency': _selectedCurrency,
        'extra_hours': double.tryParse(_extraHoursController.text),
        'agency_fee_percentage': double.tryParse(_agencyFeeController.text),
        'tax_percentage': double.tryParse(_taxController.text),
        'additional_fees': double.tryParse(_additionalFeesController.text),
        'status': _selectedStatus,
        'payment_status': _selectedPaymentStatus,
        'notes':
            _notesController.text.isNotEmpty ? _notesController.text : null,
        'job_id': jobId,
        'call_time': _formatTimeOfDay(_callTime),
      };

      // Add file data if files were uploaded
      if (fileData != null) {
        jobData['file_data'] = fileData;
      }

      if (_endDate != null) {
        jobData['end_date'] = _endDate!.toIso8601String().split('T')[0];
        jobData['is_multi_day'] = true;
      } else {
        jobData['is_multi_day'] = false;
      }

      // Multi-day job data
      if (_isDateRange && _separateDailyTimes && _dailyCallTimes.isNotEmpty) {
        jobData['has_daily_schedule'] = true;
        jobData['daily_call_times'] = _dailyCallTimes.map(
          (date, time) => MapEntry(
              date.toIso8601String().split('T')[0], _formatTimeOfDay(time)),
        );
        jobData['daily_start_times'] = _dailyStartTimes.map(
          (date, time) => MapEntry(
              date.toIso8601String().split('T')[0], _formatTimeOfDay(time)),
        );
        jobData['daily_end_times'] = _dailyEndTimes.map(
          (date, time) => MapEntry(
              date.toIso8601String().split('T')[0], _formatTimeOfDay(time)),
        );
      } else {
        jobData['has_daily_schedule'] = false;
      }

      if (widget.job != null) {
        // Update existing job
        await JobsService.update(widget.job!.id!, jobData);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job updated successfully')),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        // Create new job
        await JobsService.create(jobData);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job created successfully')),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      }
    } catch (e) {
      setState(() {
        _error = widget.job != null
            ? 'Failed to update job: $e'
            : 'Failed to create job: $e';
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
    return AppLayout(
      currentPage: '/new-job',
      title: widget.job != null ? 'Edit Job' : 'New Job',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new jobs (not when editing)
              if (widget.job == null) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  onAutoSubmit: () {
                    debugPrint('Auto-submitting job form after OCR...');
                    _createJob();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information Section
              _buildSectionHeader('Basic Information', Icons.info_outline),
              const SizedBox(height: 16),

              _formNavigation.createInputField(
                label: 'Client Name *',
                controller: _clientNameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a client name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Job Type Section
              const Text(
                'Job Type *',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              if (_isCustomType) ...[
                Row(
                  children: [
                    Expanded(
                      child: _formNavigation.createInputField(
                        controller: _customJobTypeController,
                        placeholder: 'Enter custom job type',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Job type is required';
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
                          _customJobTypeController.clear();
                        });
                      },
                      text: 'Cancel',
                      variant: ButtonVariant.outline,
                    ),
                  ],
                ),
              ] else ...[
                SafeDropdown(
                  value: _selectedJobType,
                  items: _jobTypes,
                  labelText: 'Job Type',
                  hintText: 'Select job type',
                  onChanged: (value) {
                    if (value == 'Add manually') {
                      setState(() {
                        _isCustomType = true;
                        _selectedJobType = '';
                      });
                    } else {
                      setState(() {
                        _selectedJobType = value ?? 'Add manually';
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Job type is required';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),

              // Date Range Section
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Start Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateFormat('MMM d, yyyy').format(_selectedDate),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a date';
                        }
                        return null;
                      },
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
                            // Clear end date if it's before start date
                            if (_endDate != null && _endDate!.isBefore(date)) {
                              _endDate = null;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  if (_isDateRange) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'End Date *',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        controller: TextEditingController(
                          text: _endDate != null
                              ? DateFormat('MMM d, yyyy').format(_endDate!)
                              : '',
                        ),
                        validator: (value) {
                          if (_isDateRange &&
                              (value == null || value.isEmpty)) {
                            return 'Please select end date';
                          }
                          return null;
                        },
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ??
                                _selectedDate.add(const Duration(days: 1)),
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
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text(
                  'Multi-day Job',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                subtitle: const Text(
                  'Enable for jobs spanning multiple days',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                value: _isDateRange,
                onChanged: (value) {
                  setState(() {
                    _isDateRange = value ?? false;
                    if (!_isDateRange) {
                      _endDate = null;
                      _separateDailyTimes = false;
                      _dailyCallTimes.clear();
                      _dailyStartTimes.clear();
                      _dailyEndTimes.clear();
                    }
                  });
                },
                activeColor: AppTheme.goldColor,
              ),
              const SizedBox(height: 16),
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

              const SizedBox(height: 24),

              // Schedule Section
              _buildSectionHeader('Schedule & Timing', Icons.schedule),
              const SizedBox(height: 16),

              // Call Time Field
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Call Time',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.access_time),
                        helperText: 'Time to arrive on set',
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _callTime != null
                            ? _formatTimeOfDay(_callTime)
                            : '',
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.play_arrow),
                        helperText: 'Work start time',
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _startTime != null
                            ? _formatTimeOfDay(_startTime)
                            : '',
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
                        suffixIcon: Icon(Icons.stop),
                        helperText: 'Work end time',
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text:
                            _endTime != null ? _formatTimeOfDay(_endTime) : '',
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

              // Multi-day time management
              if (_isDateRange) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text(
                    'Separate times for each day',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Set different call times and work hours for each day',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: _separateDailyTimes,
                  onChanged: (value) {
                    setState(() {
                      _separateDailyTimes = value ?? false;
                      if (!_separateDailyTimes) {
                        _dailyCallTimes.clear();
                        _dailyStartTimes.clear();
                        _dailyEndTimes.clear();
                      }
                    });
                  },
                  activeColor: AppTheme.goldColor,
                ),
              ],

              // Duration Display
              if (_startTime != null && _endTime != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.goldColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 24,
                            color: AppTheme.goldColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Duration: ${_calculateDuration()?.inHours}h ${(_calculateDuration()?.inMinutes ?? 0) % 60}m',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (_isOvernightDuration()) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange[300],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Overnight duration detected',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[300],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Daily Schedule Management for Multi-day Jobs
              if (_isDateRange && _separateDailyTimes && _endDate != null) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Daily Schedule', Icons.calendar_view_day),
                const SizedBox(height: 16),
                ..._buildDailyTimeFields(),
              ],

              const SizedBox(height: 24),

              // Financial Information Section
              _buildSectionHeader('Financial Details', Icons.attach_money),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _formNavigation.createInputField(
                      label: 'Rate',
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final rate = double.tryParse(value);
                          if (rate == null) {
                            return 'Please enter a valid number';
                          }
                        }
                        return null;
                      },
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
                        setState(() {
                          _selectedCurrency = value ?? 'USD';
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Team & Agent Section
              _buildSectionHeader('Team & Agent', Icons.people),
              const SizedBox(height: 16),

              // Agent Selection
              AgentDropdown(
                selectedAgentId: _selectedAgentId,
                labelText: 'Booking Agent *',
                hintText: 'Select an agent',
                isRequired: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a booking agent';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _selectedAgentId = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Additional Details Section
              _buildSectionHeader('Additional Details', Icons.description),
              const SizedBox(height: 16),

              _formNavigation.createInputField(
                label: 'Notes',
                controller: _notesController,
                maxLines: 3,
                placeholder: 'Add any additional notes or requirements...',
              ),

              const SizedBox(height: 24),

              // Advanced Financial Section
              _buildSectionHeader(
                  'Advanced Financial Details', Icons.calculate),
              const SizedBox(height: 16),

              // Usage Rate
              TextFormField(
                controller: _usageController,
                decoration: const InputDecoration(
                  labelText: 'Usage rate (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),

              const SizedBox(height: 16),

              // Extra Hours
              TextFormField(
                controller: _extraHoursController,
                decoration: const InputDecoration(
                  labelText: 'Extra hours (calculated at 10% of rate per hour)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (value) {
                  setState(() {}); // Trigger rebuild for calculation
                },
              ),

              const SizedBox(height: 16),

              // Agency Fee and Tax
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _agencyFeeController,
                      decoration: const InputDecoration(
                        labelText: 'Agency Fee %',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (value) {
                        setState(() {}); // Trigger rebuild for calculation
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _taxController,
                      decoration: const InputDecoration(
                        labelText: 'Tax %',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (value) {
                        setState(() {}); // Trigger rebuild for calculation
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Additional Fees
              TextFormField(
                controller: _additionalFeesController,
                decoration: const InputDecoration(
                  labelText: 'Additional fees',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (value) {
                  setState(() {}); // Trigger rebuild for calculation
                },
              ),

              const SizedBox(height: 24),

              // Status Management Section
              _buildSectionHeader('Status Management', Icons.flag),
              const SizedBox(height: 16),

              // Enhanced Job Status
              Container(
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
                          _getStatusIcon(_selectedStatus),
                          color: _getStatusColor(_selectedStatus),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Job Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.goldColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SafeDropdown(
                      value: _selectedStatus,
                      items: _statusOptions,
                      labelText: 'Current Status',
                      hintText: 'Select job status',
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'Scheduled';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusDescription(_selectedStatus),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Status
              SafeDropdown(
                value: _selectedPaymentStatus,
                items: _paymentStatusOptions,
                labelText: 'Payment Status',
                hintText: 'Select payment status',
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentStatus = value ?? 'Unpaid';
                  });
                },
              ),

              const SizedBox(height: 24),

              // Documents & Files Section
              _buildSectionHeader('Documents & Files', Icons.attach_file),
              const SizedBox(height: 16),

              // File Upload Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withValues(alpha: 0.3),
                  border: Border.all(
                      color: AppTheme.goldColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file,
                            color: AppTheme.goldColor, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Documents',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Contracts, invoices, schedules, and other documents',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Files'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.goldColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),

                    // Show existing files using FilePreviewWidget if editing
                    if (widget.job != null && widget.job!.fileData != null) ...[
                      const SizedBox(height: 16),
                      FilePreviewWidget(
                        fileData: widget.job!.fileData,
                        showTitle: false,
                        maxFilesToShow: 10,
                      ),
                    ],

                    // Show newly selected files
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...List.generate(_selectedFiles.length, (index) {
                        final file = _selectedFiles[index];
                        final isExistingFile =
                            file.path != null && file.path!.startsWith('http');

                        final category = _getFileCategory(file.extension);
                        final categoryColor = _getCategoryColor(category);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[800]?.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: categoryColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  FileUploadService.getFileIcon(file.extension),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: categoryColor.withValues(
                                                alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: categoryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          FileUploadService.getFileSize(
                                              file.size),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isExistingFile) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Existing file',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[300],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeFile(index),
                                icon: const Icon(Icons.close, size: 18),
                                color: Colors.red[300],
                                tooltip: 'Remove file',
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else if (widget.job == null ||
                        widget.job!.fileData == null) ...[
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

              const SizedBox(height: 24),

              // Financial Summary
              if (_rateController.text.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.goldColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Financial Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Base amounts
                      _buildSummaryRow('Day Rate',
                          double.tryParse(_rateController.text) ?? 0),
                      if (_usageController.text.isNotEmpty)
                        _buildSummaryRow('Usage',
                            double.tryParse(_usageController.text) ?? 0),
                      if (_extraHoursController.text.isNotEmpty)
                        _buildSummaryRow(
                            'Extra Hours (${_extraHoursController.text}h × 10%)',
                            _calculateExtraHours()),
                      if (_additionalFeesController.text.isNotEmpty)
                        _buildSummaryRow(
                            'Additional Fees',
                            double.tryParse(_additionalFeesController.text) ??
                                0),

                      // Subtotal
                      const Divider(color: Colors.grey),
                      _buildSummaryRow('Subtotal', _calculateSubtotal(),
                          isSubtotal: true),

                      // Deductions
                      if (_agencyFeeController.text.isNotEmpty &&
                          double.tryParse(_agencyFeeController.text) != 0)
                        _buildSummaryRow(
                            'Agency Fee (${_agencyFeeController.text}%)',
                            -_calculateAgencyFee(),
                            isDeduction: true),
                      if (_taxController.text.isNotEmpty &&
                          double.tryParse(_taxController.text) != 0)
                        _buildSummaryRow(
                            'Tax (${_taxController.text}%)', -_calculateTax(),
                            isDeduction: true),

                      // Final total
                      const Divider(color: Colors.white),
                      _buildSummaryRow('Net Total', _calculateTotal(),
                          isTotal: true),
                    ],
                  ),
                ),
              ],

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
                  text: widget.job != null ? 'Update Job' : 'Create Job',
                  variant: ButtonVariant.primary,
                  onPressed: _isLoading ? null : _createJob,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDailyTimeFields() {
    if (_endDate == null) return [];

    final List<Widget> fields = [];
    final List<DateTime> days = _getDaysBetweenDates(_selectedDate, _endDate!);

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayName = DateFormat('EEEE, MMM d').format(day);

      fields.add(
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            border:
                Border.all(color: AppTheme.goldColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[900],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day ${i + 1}: $dayName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.goldColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Call Time',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _dailyCallTimes[day] != null
                            ? _formatTimeOfDay(_dailyCallTimes[day])
                            : '',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _dailyCallTimes[day] ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _dailyCallTimes[day] = time;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.play_arrow),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _dailyStartTimes[day] != null
                            ? _formatTimeOfDay(_dailyStartTimes[day])
                            : '',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _dailyStartTimes[day] ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _dailyStartTimes[day] = time;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.stop),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _dailyEndTimes[day] != null
                            ? _formatTimeOfDay(_dailyEndTimes[day])
                            : '',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _dailyEndTimes[day] ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _dailyEndTimes[day] = time;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return fields;
  }

  List<DateTime> _getDaysBetweenDates(DateTime start, DateTime end) {
    final List<DateTime> days = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Scheduled':
        return Icons.schedule;
      case 'In Progress':
        return Icons.play_circle_filled;
      case 'Completed':
        return Icons.check_circle;
      case 'Canceled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'Scheduled':
        return 'Job is confirmed and scheduled';
      case 'In Progress':
        return 'Job is currently being executed';
      case 'Completed':
        return 'Job has been successfully completed';
      case 'Canceled':
        return 'Job was canceled before completion';
      default:
        return 'Select a status to see description';
    }
  }
}
