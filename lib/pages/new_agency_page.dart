import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';

import 'package:new_flutter/services/agencies_service.dart';
import 'package:new_flutter/providers/agencies_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:new_flutter/services/file_upload_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NewAgencyPage extends StatefulWidget {
  const NewAgencyPage({super.key});

  @override
  State<NewAgencyPage> createState() => _NewAgencyPageState();
}

class _NewAgencyPageState extends State<NewAgencyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _notesController = TextEditingController();

  // Form Navigation Helper
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  // Field navigation

  // Manual focus nodes for better control
  late List<FocusNode> _manualFocusNodes;

  // Contract fields
  final _contractSignedController = TextEditingController();
  final _contractExpiredController = TextEditingController();

  // Main Booker
  final _mainBookerNameController = TextEditingController();
  final _mainBookerEmailController = TextEditingController();
  final _mainBookerPhoneController = TextEditingController();

  // Finance Contact
  final _financeNameController = TextEditingController();
  final _financeEmailController = TextEditingController();
  final _financePhoneController = TextEditingController();

  String _selectedStatus = 'active';
  String _selectedType = 'representing';
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingId;
  DateTime? _contractSigned;
  DateTime? _contractExpired;

  final List<String> _statusOptions = ['active', 'inactive', 'pending'];
  final List<String> _typeOptions = ['representing', 'mother agency'];

  // Document files
  final List<PlatformFile> _documentFiles = [];

  // Existing contract URL when editing
  String? _existingContractUrl;

  @override
  void initState() {
    super.initState();

    // Initialize manual focus nodes for all text fields (13 total)
    _manualFocusNodes = List.generate(13, (index) => FocusNode());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _loadAgency(args);
      }
    });
  }

  Future<void> _loadAgency(String id) async {
    setState(() {
      _isLoading = true;
      _isEditing = true;
      _editingId = id;
    });

    try {
      final agency = await AgenciesService.getById(id);
      if (agency != null) {
        setState(() {
          _nameController.text = agency.name;
          _selectedType = agency.agencyType ?? 'representing';
          _websiteController.text = agency.website ?? '';
          _addressController.text = agency.address ?? '';
          _cityController.text = agency.city ?? '';
          _countryController.text = agency.country ?? '';
          _commissionRateController.text = agency.commissionRate.toString();
          _notesController.text = agency.notes ?? '';
          _selectedStatus = agency.status ?? 'active';

          // Contract dates
          if (agency.contractSigned != null) {
            _contractSigned = agency.contractSigned;
            _contractSignedController.text =
                '${agency.contractSigned!.day}/${agency.contractSigned!.month}/${agency.contractSigned!.year}';
          }
          if (agency.contractExpired != null) {
            _contractExpired = agency.contractExpired;
            _contractExpiredController.text =
                '${agency.contractExpired!.day}/${agency.contractExpired!.month}/${agency.contractExpired!.year}';
          }

          // Load existing contract document if available
          if (agency.contract != null && agency.contract!.isNotEmpty) {
            _existingContractUrl = agency.contract;
            debugPrint('Existing contract found: ${agency.contract}');
          }

          // Main Booker
          if (agency.mainBooker != null) {
            _mainBookerNameController.text = agency.mainBooker!.name;
            _mainBookerEmailController.text = agency.mainBooker!.email;
            _mainBookerPhoneController.text = agency.mainBooker!.phone;
          }

          // Finance Contact
          if (agency.financeContact != null) {
            _financeNameController.text = agency.financeContact!.name;
            _financeEmailController.text = agency.financeContact!.email;
            _financePhoneController.text = agency.financeContact!.phone;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading agency: $e'),
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
    _nameController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _commissionRateController.dispose();
    _notesController.dispose();
    _mainBookerNameController.dispose();
    _mainBookerEmailController.dispose();
    _mainBookerPhoneController.dispose();
    _financeNameController.dispose();
    _financeEmailController.dispose();
    _financePhoneController.dispose();
    _contractSignedController.dispose();
    _contractExpiredController.dispose();
    _formNavigation.dispose();

    // Dispose manual focus nodes
    for (final focusNode in _manualFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  void _handleOcrDataExtracted(Map<String, dynamic> data) {
    debugPrint('🏢 OCR data extracted for agency: $data');

    setState(() {
      // Map agency name
      if (data['agencyName'] != null) {
        _nameController.text = data['agencyName'];
        debugPrint('🏢 Set agency name: ${data['agencyName']}');
      } else if (data['name'] != null) {
        _nameController.text = data['name'];
        debugPrint('🏢 Set agency name from name: ${data['name']}');
      } else if (data['company'] != null) {
        _nameController.text = data['company'];
        debugPrint('🏢 Set agency name from company: ${data['company']}');
      } else if (data['organization'] != null) {
        _nameController.text = data['organization'];
        debugPrint(
            '🏢 Set agency name from organization: ${data['organization']}');
      }

      // Map agency type
      if (data['agencyType'] != null || data['type'] != null) {
        final typeStr =
            (data['agencyType'] ?? data['type']).toString().toLowerCase();
        debugPrint('🏢 Processing agency type: $typeStr');
        if (typeStr.contains('mother') || typeStr.contains('parent')) {
          _selectedType = 'mother agency';
          debugPrint('🏢 Set agency type to: mother agency');
        } else if (typeStr.contains('representing') ||
            typeStr.contains('represent')) {
          _selectedType = 'representing';
          debugPrint('🏢 Set agency type to: representing');
        }
      }

      // Map website
      if (data['website'] != null) {
        _websiteController.text = data['website'];
        debugPrint('🏢 Set website: ${data['website']}');
      } else if (data['url'] != null) {
        _websiteController.text = data['url'];
        debugPrint('🏢 Set website from url: ${data['url']}');
      }

      // Map address
      if (data['address'] != null) {
        _addressController.text = data['address'];
      }

      // Map city
      if (data['city'] != null) {
        _cityController.text = data['city'];
      }

      // Map country
      if (data['country'] != null) {
        _countryController.text = data['country'];
      }

      // Map commission rate
      if (data['commissionRate'] != null || data['commission'] != null) {
        final rateValue = data['commissionRate'] ?? data['commission'];
        final cleanRate = rateValue.toString().replaceAll('%', '');
        _commissionRateController.text = cleanRate;
        debugPrint('🏢 Set commission rate: $cleanRate (from $rateValue)');
      }

      // Map status
      if (data['status'] != null) {
        final status = data['status'].toString().toLowerCase();
        if (status.contains('active')) {
          _selectedStatus = 'active';
        } else if (status.contains('inactive')) {
          _selectedStatus = 'inactive';
        } else if (status.contains('pending')) {
          _selectedStatus = 'pending';
        }
      }

      // Map main booker information
      if (data['mainBookerName'] != null ||
          data['bookerName'] != null ||
          data['contactName'] != null) {
        final bookerName =
            data['mainBookerName'] ?? data['bookerName'] ?? data['contactName'];
        _mainBookerNameController.text = bookerName;
      }

      if (data['mainBookerEmail'] != null ||
          data['bookerEmail'] != null ||
          data['email'] != null) {
        final bookerEmail =
            data['mainBookerEmail'] ?? data['bookerEmail'] ?? data['email'];
        _mainBookerEmailController.text = bookerEmail;
      }

      if (data['mainBookerPhone'] != null ||
          data['bookerPhone'] != null ||
          data['phone'] != null) {
        final bookerPhone =
            data['mainBookerPhone'] ?? data['bookerPhone'] ?? data['phone'];
        _mainBookerPhoneController.text = bookerPhone;
      }

      // Map finance contact information
      if (data['financeContactName'] != null || data['financeName'] != null) {
        final financeName = data['financeContactName'] ?? data['financeName'];
        _financeNameController.text = financeName;
      }

      if (data['financeContactEmail'] != null || data['financeEmail'] != null) {
        final financeEmail =
            data['financeContactEmail'] ?? data['financeEmail'];
        _financeEmailController.text = financeEmail;
      }

      if (data['financeContactPhone'] != null || data['financePhone'] != null) {
        final financePhone =
            data['financeContactPhone'] ?? data['financePhone'];
        _financePhoneController.text = financePhone;
      }

      // Map contract dates
      if (data['contractSigned'] != null ||
          data['contractSignedDate'] != null) {
        try {
          final dateStr = data['contractSigned'] ?? data['contractSignedDate'];
          _contractSigned = DateTime.parse(dateStr);
          _contractSignedController.text =
              '${_contractSigned!.day}/${_contractSigned!.month}/${_contractSigned!.year}';
        } catch (e) {
          debugPrint(
              'Could not parse contract signed date: ${data['contractSigned']}');
        }
      }

      if (data['contractExpired'] != null ||
          data['contractExpiredDate'] != null) {
        try {
          final dateStr =
              data['contractExpired'] ?? data['contractExpiredDate'];
          _contractExpired = DateTime.parse(dateStr);
          _contractExpiredController.text =
              '${_contractExpired!.day}/${_contractExpired!.month}/${_contractExpired!.year}';
        } catch (e) {
          debugPrint(
              'Could not parse contract expired date: ${data['contractExpired']}');
        }
      }

      // Map notes
      if (data['notes'] != null) {
        _notesController.text = data['notes'];
      } else if (data['description'] != null) {
        _notesController.text = data['description'];
      }

      // Add additional information to notes if available
      final additionalInfo = <String>[];

      if (data['services'] != null) {
        additionalInfo.add('Services: ${data['services']}');
      }

      if (data['specialization'] != null) {
        additionalInfo.add('Specialization: ${data['specialization']}');
      }

      if (data['territories'] != null) {
        additionalInfo.add('Territories: ${data['territories']}');
      }

      if (additionalInfo.isNotEmpty) {
        final currentNotes = _notesController.text;
        final additional = additionalInfo.join('\n');
        _notesController.text =
            currentNotes.isEmpty ? additional : '$currentNotes\n\n$additional';
      }
    });

    debugPrint('🏢 Agency form populated with OCR data');

    // Add ALL extracted data to notes for complete record
    _appendAllExtractedDataToNotes(data);
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate agency ID for file organization
      final agencyId =
          _editingId ?? DateTime.now().millisecondsSinceEpoch.toString();

      // Upload documents if any
      List<String> documentUrls = [];

      if (_documentFiles.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 16),
                  Text('Uploading documents...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        // Upload document files
        documentUrls = await FileUploadService.uploadEventFiles(
          files: _documentFiles,
          eventId: agencyId,
          eventType: 'agency_documents',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }

      final agencyData = {
        'name': _nameController.text,
        'agency_type': _selectedType,
        'website':
            _websiteController.text.isEmpty ? null : _websiteController.text,
        'address':
            _addressController.text.isEmpty ? null : _addressController.text,
        'city': _cityController.text.isEmpty ? null : _cityController.text,
        'country':
            _countryController.text.isEmpty ? null : _countryController.text,
        'commission_rate':
            double.tryParse(_commissionRateController.text) ?? 0.0,
        'contract_signed': _contractSigned?.toIso8601String(),
        'contract_expired': _contractExpired?.toIso8601String(),
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'status': _selectedStatus,
        'main_booker': {
          'name': _mainBookerNameController.text,
          'email': _mainBookerEmailController.text,
          'phone': _mainBookerPhoneController.text,
        },
        'finance_contact': {
          'name': _financeNameController.text,
          'email': _financeEmailController.text,
          'phone': _financePhoneController.text,
        },
        'contract': _existingContractUrl ??
            (documentUrls.isNotEmpty ? documentUrls.first : null),
        'documents': documentUrls.isNotEmpty ? documentUrls : null,
      };

      if (_isEditing && _editingId != null) {
        await AgenciesService.update(_editingId!, agencyData);
        if (mounted) {
          Navigator.pop(context, _editingId);
        }
      } else {
        final createdAgencyId = await AgenciesProvider().createAgency(agencyData);
        if (mounted) {
          if (createdAgencyId != null) {
            Navigator.pop(context, createdAgencyId);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create agency'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving agency: $e'),
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
        currentPage: '/new-agency',
        title: _isEditing ? 'Edit Agency' : 'New Agency',
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AppLayout(
      currentPage: '/new-agency',
      title: _isEditing ? 'Edit Agency' : 'New Agency',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new agencies (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  // Auto-submit disabled for testing
                  // onAutoSubmit: () {
                  //   debugPrint('Auto-submitting agency form after OCR...');
                  //   _handleSubmit();
                  // },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information
              _buildSectionCard(
                'Basic Information',
                [
                  TextFormField(
                    controller: _nameController,
                    focusNode: _manualFocusNodes[0], // Agency Name
                    decoration: const InputDecoration(
                      labelText: 'Agency Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter agency name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTypeField(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _websiteController,
                    focusNode: _manualFocusNodes[
                        1], // Website (index 2 in field sequence, but focus node 1)
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    focusNode: _manualFocusNodes[2], // Address
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          focusNode: _manualFocusNodes[3], // City
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _countryController,
                          focusNode: _manualFocusNodes[4], // Country
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _commissionRateController,
                          focusNode: _manualFocusNodes[5], // Commission Rate
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Commission Rate (%)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatusField(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main Booker
              _buildSectionCard(
                'Main Booker',
                [
                  TextFormField(
                    controller: _mainBookerNameController,
                    focusNode: _manualFocusNodes[6], // Main Booker Name
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter main booker name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mainBookerEmailController,
                    focusNode: _manualFocusNodes[7], // Main Booker Email
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter main booker email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mainBookerPhoneController,
                    focusNode: _manualFocusNodes[8], // Main Booker Phone
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Finance Contact
              _buildSectionCard(
                'Finance Contact',
                [
                  TextFormField(
                    controller: _financeNameController,
                    focusNode: _manualFocusNodes[9], // Finance Name
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _financeEmailController,
                    focusNode: _manualFocusNodes[10], // Finance Email
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _financePhoneController,
                    focusNode: _manualFocusNodes[11], // Finance Phone
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Contract Information
              _buildSectionCard(
                'Contract Information',
                [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Contract Signed Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          controller: _contractSignedController,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _contractSigned ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                _contractSigned = date;
                                _contractSignedController.text =
                                    '${date.day}/${date.month}/${date.year}';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Contract Expired Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          controller: _contractExpiredController,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _contractExpired ??
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                _contractExpired = date;
                                _contractExpiredController.text =
                                    '${date.day}/${date.month}/${date.year}';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Documents
              _buildSectionCard(
                'Documents',
                [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickDocumentFiles(),
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Add Documents'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Show existing contract if editing
                  if (_isEditing && _existingContractUrl != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green[600]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.green[900]!.withValues(alpha: 0.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[400]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Existing Contract Document',
                                  style: TextStyle(
                                    color: Colors.green[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _viewExistingContract(),
                                icon: Icon(Icons.visibility,
                                    color: Colors.blue[400]),
                                tooltip: 'View Contract',
                              ),
                              IconButton(
                                onPressed: () => _removeExistingContract(),
                                icon:
                                    Icon(Icons.delete, color: Colors.red[400]),
                                tooltip: 'Remove Contract',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Display the actual document content
                          _buildDocumentPreview(_existingContractUrl!),
                        ],
                      ),
                    ),
                  ],

                  // Display selected document files
                  if (_documentFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...List.generate(_documentFiles.length, (index) {
                      final file = _documentFiles[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[600]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[850],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description,
                                color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.name,
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeDocumentFile(index),
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
              const SizedBox(height: 24),

              // Notes
              _buildSectionCard(
                'Notes',
                [
                  TextFormField(
                    controller: _notesController,
                    focusNode: _manualFocusNodes[12], // Notes
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
                          : (_isEditing ? 'Update Agency' : 'Create Agency'),
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
            initialValue: _selectedStatus,
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
                _selectedStatus = value ?? 'active';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Agency Type',
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
            initialValue: _selectedType,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
            items: _typeOptions.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value ?? 'representing';
              });
            },
          ),
        ),
      ],
    );
  }

  // File handling methods
  Future<void> _pickDocumentFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _documentFiles.addAll(result.files);
          // If we're editing and adding new documents, clear the existing contract
          if (_isEditing && _existingContractUrl != null) {
            _existingContractUrl = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking document files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeDocumentFile(int index) {
    setState(() {
      _documentFiles.removeAt(index);
    });
  }

  void _viewExistingContract() {
    if (_existingContractUrl != null) {
      // Open the existing contract URL
      launchUrl(
        Uri.parse(_existingContractUrl!),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _removeExistingContract() {
    setState(() {
      _existingContractUrl = null;
    });
  }

  Widget _buildDocumentPreview(String documentUrl) {
    // Extract just the filename from the URL
    final fileName = documentUrl.split('/').last.split('?').first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
