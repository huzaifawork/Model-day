import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/services/auth_service.dart';
import 'package:new_flutter/services/email_service.dart';
import 'package:new_flutter/services/events_service.dart';
import 'package:new_flutter/providers/approval_notification_provider.dart';
import 'package:new_flutter/services/user_service.dart';
// Removed unused import
import 'package:provider/provider.dart';
import 'package:new_flutter/widgets/enhanced_icon.dart';
import 'package:intl/intl.dart';
import 'package:new_flutter/services/logging_service.dart';

class SubmitEventPage extends StatefulWidget {
  const SubmitEventPage({super.key});

  @override
  State<SubmitEventPage> createState() => _SubmitEventPageState();
}

class _SubmitEventPageState extends State<SubmitEventPage> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _agentEmailController = TextEditingController();
  final _modelEmailController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _dayRateController = TextEditingController();
  final _notesController = TextEditingController();

  // Form state
  bool _isLoading = false;
  bool _isEventSectionExpanded = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedEventType = 'Option';
  String _selectedCurrency = 'USD';

  // Event types
  final List<String> _eventTypes = [
    'Option',
    'Job',
    'Direct Option',
    'Direct Booking',
    'Casting',
    'Test',
    'Polaroids',
    'Meeting',
    'Other'
  ];

  // Currencies
  final List<String> _currencies = [
    'USD',
    'EUR',
    'GBP',
    'CAD',
    'AUD',
    'JPY',
    'CHF',
    'SEK',
    'NOK'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  @override
  void dispose() {
    _agentEmailController.dispose();
    _modelEmailController.dispose();
    _clientNameController.dispose();
    _locationController.dispose();
    _dayRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadUserEmail() {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser?.email != null) {
      // Set the current user as the agent (the one sending the approval request)
      // The model field should be filled manually by the user
      _agentEmailController.text = currentUser!.email!;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.goldColor,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields
    if (_agentEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter agent email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_modelEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter model email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_clientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter client name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        // Create the event data
        final eventData = {
          'type': _selectedEventType.toLowerCase().replaceAll(' ', '_'),
          'client_name': _clientNameController.text.trim(),
          'location': _locationController.text.trim(),
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'day_rate': double.tryParse(_dayRateController.text) ?? 0.0,
          'currency': _selectedCurrency,
          'notes': _notesController.text.trim(),
          'agent_email': _agentEmailController.text.trim(),
          'model_email': _modelEmailController.text.trim(),
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'created_by': currentUser.uid,
        };

        // Create the event in Firestore
        final createdEvent = await EventsService().createEvent(eventData);

        // Send email notification to the model
        final agentName = currentUser.displayName ??
            _agentEmailController.text.split('@').first;

        final emailSent = await EmailService.sendEventNotification(
          modelEmail: _modelEmailController.text.trim(),
          agentEmail: _agentEmailController.text.trim(),
          agentName: agentName,
          eventType: _selectedEventType,
          clientName: _clientNameController.text.trim(),
          eventDate: DateFormat('MMM dd, yyyy').format(_selectedDate),
          location: _locationController.text.trim(),
          dayRate: _dayRateController.text.isNotEmpty
              ? _dayRateController.text
              : '0',
          currency: _selectedCurrency,
          notes: _notesController.text.trim(),
        );

        // Create approval notification for the model
        if (createdEvent != null && mounted) {
          try {
            final notificationProvider =
                context.read<ApprovalNotificationProvider>();

            // Get the actual user ID from the email
            final modelUser = await UserService.getUserByEmail(
                _modelEmailController.text.trim());
            if (modelUser != null && modelUser.id != null) {
              await notificationProvider.createApprovalSentNotification(
                recipientUserId: modelUser.id!,
                senderUserId: currentUser.uid,
                senderUserName: agentName,
                senderUserEmail: _agentEmailController.text.trim(),
                event: createdEvent,
              );
              LoggingService.logInfo(
                  'Approval notification created for model: ${_modelEmailController.text.trim()}');
            } else {
              LoggingService.logWarning(
                  'Could not find user ID for email: ${_modelEmailController.text.trim()}');
            }
          } catch (e) {
            LoggingService.logError('Error creating approval notification', e);
            // Don't fail the entire process if notification creation fails
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emailSent
                  ? '✅ Event created and notification sent to ${_modelEmailController.text.trim()}'
                  : '✅ Event created! (Email notification failed to send)'),
              backgroundColor: emailSent ? AppTheme.goldColor : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );

          // Clear the form
          _clearForm();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating event: $e'),
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

  void _clearForm() {
    _agentEmailController.clear();
    _modelEmailController.clear();
    _clientNameController.clear();
    _locationController.clear();
    _dayRateController.clear();
    _notesController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedEventType = 'Option';
      _selectedCurrency = 'USD';
      _isEventSectionExpanded = false;
    });
    // Reload user email as agent after clearing
    _loadUserEmail();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/submit-event',
      title: 'Submit Event for Model',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.goldColor.withValues(alpha: 0.1),
                      AppTheme.goldColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.goldColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.goldColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: EnhancedIcon(
                              Icons.event_note,
                              color: AppTheme.goldColor,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Event for Model',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Fill in the details below to create and send an event to your model',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Agent Email Field
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E2E2E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Agent Email',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.lock,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '(Locked)',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _agentEmailController,
                      readOnly: true, // Make field read-only
                      decoration: InputDecoration(
                        hintText: 'agent@agency.com',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(
                            0xFF1A1A1A), // Darker to show it's locked
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF404040)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF404040)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF404040)),
                        ),
                        prefixIcon: const SizedBox(
                          width: 48,
                          height: 48,
                          child: EnhancedIcon(
                            Icons.email,
                            color: AppTheme.goldColor,
                            size: 18,
                          ),
                        ),
                        suffixIcon: const SizedBox(
                          width: 48,
                          height: 48,
                          child: EnhancedIcon(
                            Icons.lock,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                          color: Colors.grey), // Grey text to show it's locked
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter agent email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Model Email Field
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E2E2E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Model Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _modelEmailController,
                      decoration: InputDecoration(
                        hintText: 'model@email.com',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.goldColor,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const SizedBox(
                          width: 48,
                          height: 48,
                          child: EnhancedIcon(
                            Icons.person_outline,
                            color: AppTheme.goldColor,
                            size: 18,
                          ),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter model email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Event Creation Section (Collapsed Card)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E2E2E)),
                ),
                child: Column(
                  children: [
                    // Header with expand/collapse
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isEventSectionExpanded = !_isEventSectionExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: EnhancedIcon(
                                Icons.event,
                                color: AppTheme.goldColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Event Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            EnhancedIcon(
                              _isEventSectionExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppTheme.goldColor,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable content
                    if (_isEventSectionExpanded) ...[
                      const Divider(color: Color(0xFF2E2E2E), height: 1),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Event Type and Client Name Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Event Type',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedEventType,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFF2A2A2A),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: AppTheme.goldColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        dropdownColor: const Color(0xFF2A2A2A),
                                        style: const TextStyle(
                                            color: Colors.white),
                                        items: _eventTypes.map((String type) {
                                          return DropdownMenuItem<String>(
                                            value: type,
                                            child: Text(type),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedEventType = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Client Name',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _clientNameController,
                                        decoration: InputDecoration(
                                          hintText: 'e.g., Nike, Samsung',
                                          hintStyle: const TextStyle(
                                              color: Colors.grey),
                                          filled: true,
                                          fillColor: const Color(0xFF2A2A2A),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: AppTheme.goldColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Date and Location Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Date',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: _selectDate,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2A2A2A),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const EnhancedIcon(
                                                Icons.calendar_today,
                                                color: AppTheme.goldColor,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                DateFormat('MMM dd, yyyy')
                                                    .format(_selectedDate),
                                                style: const TextStyle(
                                                    color: Colors.white),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Location',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _locationController,
                                        decoration: InputDecoration(
                                          hintText: 'Studio, City, TBC',
                                          hintStyle: const TextStyle(
                                              color: Colors.grey),
                                          filled: true,
                                          fillColor: const Color(0xFF2A2A2A),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: AppTheme.goldColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Day Rate and Currency Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Day Rate',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _dayRateController,
                                        decoration: InputDecoration(
                                          hintText: '1000',
                                          hintStyle: const TextStyle(
                                              color: Colors.grey),
                                          filled: true,
                                          fillColor: const Color(0xFF2A2A2A),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: AppTheme.goldColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        style: const TextStyle(
                                            color: Colors.white),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Currency',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedCurrency,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFF2A2A2A),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: AppTheme.goldColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        dropdownColor: const Color(0xFF2A2A2A),
                                        style: const TextStyle(
                                            color: Colors.white),
                                        items:
                                            _currencies.map((String currency) {
                                          return DropdownMenuItem<String>(
                                            value: currency,
                                            child: Text(currency),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedCurrency = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Notes Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notes (Optional)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _notesController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Additional details, requirements, etc.',
                                    hintStyle:
                                        const TextStyle(color: Colors.grey),
                                    filled: true,
                                    fillColor: const Color(0xFF2A2A2A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.goldColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Send Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.goldColor, Color(0xFFB8976C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            EnhancedIcon(
                              Icons.send,
                              color: Colors.black,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Create Event & Send Notification',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
