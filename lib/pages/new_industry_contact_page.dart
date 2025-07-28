import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/ui/input.dart' as ui;
import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/models/industry_contact.dart';
import 'package:new_flutter/providers/industry_contacts_provider.dart';

class NewIndustryContactPage extends StatefulWidget {
  const NewIndustryContactPage({super.key});

  @override
  State<NewIndustryContactPage> createState() => _NewIndustryContactPageState();
}

class _NewIndustryContactPageState extends State<NewIndustryContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _instagramController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _notesController = TextEditingController();
  final _customJobTitleController = TextEditingController();

  String _selectedJobTitle = '';
  bool _isCustomJobTitle = false;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingId;

  final List<String> _jobTitles = [
    'Add manually',
    'Make-up artist',
    'Stylist',
    'Photographer',
    'Fashion designer',
    'Hairstylist',
    'Creative Director',
    'Art Director',
    'Producer',
    'Casting Director',
    'Model Agent',
    'Booking Agent',
    'Fashion Editor',
    'Wardrobe Stylist',
    'Set Designer',
    'Retoucher',
    'Video Director',
    'Social Media Manager'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _loadContact(args);
      }
    });
  }

  Future<void> _loadContact(String id) async {
    setState(() {
      _isLoading = true;
      _isEditing = true;
      _editingId = id;
    });

    try {
      final provider = context.read<IndustryContactsProvider>();
      // First try to get from local list, then from service
      IndustryContact? contact = provider.getContactById(id) ??
          await provider.getContactByIdFromService(id);

      if (contact != null) {
        setState(() {
          _nameController.text = contact.name;
          _companyController.text = contact.company ?? '';
          _emailController.text = contact.email ?? '';
          _mobileController.text = contact.mobile ?? '';
          _instagramController.text = contact.instagram ?? '';
          _cityController.text = contact.city ?? '';
          _countryController.text = contact.country ?? '';
          _notesController.text = contact.notes ?? '';

          // Handle job title
          if (contact.jobTitle != null &&
              _jobTitles.contains(contact.jobTitle)) {
            _selectedJobTitle = contact.jobTitle!;
          } else if (contact.jobTitle != null) {
            _selectedJobTitle = 'Add manually';
            _isCustomJobTitle = true;
            _customJobTitleController.text = contact.jobTitle!;
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contact: $e'),
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
    _jobTitleController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _instagramController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _notesController.dispose();
    _customJobTitleController.dispose();
    super.dispose();
  }

  void _handleOcrDataExtracted(Map<String, dynamic> data) {
    debugPrint('🏭 OCR data extracted for industry contact: $data');

    setState(() {
      // Map contact name
      if (data['name'] != null) {
        _nameController.text = data['name'];
        debugPrint('🏭 Set contact name: ${data['name']}');
      } else if (data['fullName'] != null) {
        _nameController.text = data['fullName'];
        debugPrint('🏭 Set contact name from fullName: ${data['fullName']}');
      } else if (data['contactName'] != null) {
        _nameController.text = data['contactName'];
        debugPrint(
            '🏭 Set contact name from contactName: ${data['contactName']}');
      }

      // Map job title
      if (data['jobTitle'] != null) {
        final jobTitleStr = data['jobTitle'].toString().toLowerCase();
        debugPrint('🏭 Processing job title: $jobTitleStr');

        // Try to match with existing job titles
        String? matchedJobTitle;
        for (String title in _jobTitles) {
          if (title.toLowerCase().contains(jobTitleStr) ||
              jobTitleStr.contains(title.toLowerCase())) {
            matchedJobTitle = title;
            break;
          }
        }

        if (matchedJobTitle != null && matchedJobTitle != 'Add manually') {
          _selectedJobTitle = matchedJobTitle;
          _isCustomJobTitle = false;
          debugPrint('🏭 Set job title to: $matchedJobTitle');
        } else {
          // Use custom job title
          _selectedJobTitle = 'Add manually';
          _isCustomJobTitle = true;
          _customJobTitleController.text = data['jobTitle'];
          debugPrint('🏭 Set custom job title: ${data['jobTitle']}');
        }
      }

      // Map company
      if (data['company'] != null) {
        _companyController.text = data['company'];
        debugPrint('🏭 Set company: ${data['company']}');
      }

      // Map email
      if (data['email'] != null) {
        _emailController.text = data['email'];
        debugPrint('🏭 Set email: ${data['email']}');
      }

      // Map mobile phone
      if (data['mobile'] != null) {
        _mobileController.text = data['mobile'];
        debugPrint('🏭 Set mobile: ${data['mobile']}');
      } else if (data['phone'] != null) {
        _mobileController.text = data['phone'];
        debugPrint('🏭 Set mobile from phone: ${data['phone']}');
      } else if (data['mobilePhone'] != null) {
        _mobileController.text = data['mobilePhone'];
        debugPrint('🏭 Set mobile from mobilePhone: ${data['mobilePhone']}');
      }

      // Map Instagram username
      if (data['instagram'] != null) {
        final instagram = data['instagram'].toString().replaceAll('@', '');
        _instagramController.text = instagram;
        debugPrint('🏭 Set instagram: $instagram');
      } else if (data['instagramUsername'] != null) {
        final instagram =
            data['instagramUsername'].toString().replaceAll('@', '');
        _instagramController.text = instagram;
        debugPrint('🏭 Set instagram from instagramUsername: $instagram');
      }

      // Map city
      if (data['city'] != null) {
        _cityController.text = data['city'];
        debugPrint('🏭 Set city: ${data['city']}');
      }

      // Map country
      if (data['country'] != null) {
        _countryController.text = data['country'];
        debugPrint('🏭 Set country: ${data['country']}');
      }

      // Map notes
      if (data['notes'] != null) {
        _notesController.text = data['notes'];
        debugPrint('🏭 Set notes: ${data['notes']}');
      } else if (data['description'] != null) {
        _notesController.text = data['description'];
        debugPrint('🏭 Set notes from description: ${data['description']}');
      }

      // Add additional information to notes if available
      final additionalInfo = <String>[];

      if (data['specialization'] != null) {
        additionalInfo.add('Specialization: ${data['specialization']}');
      }

      if (data['experience'] != null) {
        additionalInfo.add('Experience: ${data['experience']}');
      }

      if (data['portfolio'] != null) {
        additionalInfo.add('Portfolio: ${data['portfolio']}');
      }

      if (data['website'] != null) {
        additionalInfo.add('Website: ${data['website']}');
      }

      if (additionalInfo.isNotEmpty) {
        final currentNotes = _notesController.text;
        final additional = additionalInfo.join('\n');
        _notesController.text =
            currentNotes.isEmpty ? additional : '$currentNotes\n\n$additional';
      }
    });

    debugPrint('🏭 Industry contact form populated with OCR data');
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final contact = IndustryContact(
        id: _editingId,
        name: _nameController.text,
        jobTitle: _isCustomJobTitle
            ? _customJobTitleController.text
            : _selectedJobTitle,
        company:
            _companyController.text.isEmpty ? null : _companyController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        mobile: _mobileController.text.isEmpty ? null : _mobileController.text,
        instagram: _instagramController.text.isEmpty
            ? null
            : _instagramController.text,
        city: _cityController.text.isEmpty ? null : _cityController.text,
        country:
            _countryController.text.isEmpty ? null : _countryController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      final provider = context.read<IndustryContactsProvider>();
      bool success = false;

      if (_isEditing && _editingId != null) {
        success = await provider.updateContact(_editingId!, contact.toJson());
      } else {
        success = await provider.createContact(contact.toJson());
      }

      if (mounted) {
        if (success) {
          // Return true to indicate successful save
          Navigator.pop(context, true);
        } else {
          // Show error if save failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Failed to update contact'
                  : 'Failed to create contact'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving contact: $e'),
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
        currentPage: '/new-industry-contact',
        title: _isEditing ? 'Edit Industry Contact' : 'New Industry Contact',
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AppLayout(
      currentPage: '/new-industry-contact',
      title: _isEditing ? 'Edit Industry Contact' : 'New Industry Contact',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new industry contacts (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  onAutoSubmit: () {
                    debugPrint(
                        'Auto-submitting industry contact form after OCR...');
                    _handleSubmit();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information
              _buildSectionCard(
                'Basic Information',
                [
                  ui.Input(
                    label: 'Full Name',
                    controller: _nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter contact name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildJobTitleField(),
                  const SizedBox(height: 16),
                  ui.Input(
                    label: 'Company',
                    controller: _companyController,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Contact Information
              _buildSectionCard(
                'Contact Information',
                [
                  ui.Input(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ui.Input(
                    label: 'Mobile Phone',
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  ui.Input(
                    label: 'Instagram Username (without @)',
                    controller: _instagramController,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Location Information
              _buildSectionCard(
                'Location',
                [
                  Row(
                    children: [
                      Expanded(
                        child: ui.Input(
                          label: 'City',
                          controller: _cityController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ui.Input(
                          label: 'Country',
                          controller: _countryController,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes
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
                          : (_isEditing ? 'Update Contact' : 'Create Contact'),
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

  Widget _buildJobTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Title',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (_isCustomJobTitle)
          Row(
            children: [
              Expanded(
                child: ui.Input(
                  label: 'Custom Job Title',
                  controller: _customJobTitleController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter job title';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () {
                  setState(() {
                    _isCustomJobTitle = false;
                    _customJobTitleController.clear();
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
              value: _selectedJobTitle.isNotEmpty &&
                      _jobTitles.contains(_selectedJobTitle)
                  ? _selectedJobTitle
                  : null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              dropdownColor: Colors.black,
              style: const TextStyle(color: Colors.white),
              hint: const Text(
                'Select job title',
                style: TextStyle(color: Colors.white70),
              ),
              items: _jobTitles.map((title) {
                return DropdownMenuItem<String>(
                  value: title,
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == 'Add manually') {
                  setState(() {
                    _isCustomJobTitle = true;
                    _selectedJobTitle = '';
                  });
                } else {
                  setState(() {
                    _selectedJobTitle = value ?? '';
                  });
                }
              },
            ),
          ),
      ],
    );
  }
}
