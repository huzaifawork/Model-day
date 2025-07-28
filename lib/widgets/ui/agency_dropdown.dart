import 'package:flutter/material.dart';
import '../../models/agency.dart';
import '../../services/agencies_service.dart';
import '../../theme/app_theme.dart';

class AgencyDropdown extends StatefulWidget {
  final String? selectedAgencyId;
  final String? labelText;
  final String? hintText;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool showAddButton;
  final bool isRequired;

  const AgencyDropdown({
    super.key,
    this.selectedAgencyId,
    this.labelText = 'Agency',
    this.hintText = 'Select an agency',
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.showAddButton = true,
    this.isRequired = false,
  });

  @override
  State<AgencyDropdown> createState() => _AgencyDropdownState();
}

class _AgencyDropdownState extends State<AgencyDropdown> {
  List<Agency> _agencies = [];
  bool _isLoading = true;
  String? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.selectedAgencyId;
    _loadAgencies();
  }

  @override
  void didUpdateWidget(AgencyDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAgencyId != widget.selectedAgencyId) {
      setState(() {
        _currentValue = widget.selectedAgencyId;
      });
    }
  }

  Future<void> _loadAgencies() async {
    try {
      final agencies = await AgenciesService.list();
      if (mounted) {
        setState(() {
          _agencies = agencies;
          _isLoading = false;
          
          // Validate current value
          if (_currentValue != null && 
              !_agencies.any((agency) => agency.id == _currentValue)) {
            _currentValue = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading agencies: $e');
      if (mounted) {
        setState(() {
          _agencies = [];
          _isLoading = false;
          _currentValue = null;
        });
      }
    }
  }

  Future<void> _createNewAgency() async {
    final result = await Navigator.pushNamed(context, '/new-agency');
    if (result != null && result is String && result.isNotEmpty) {
      // Reload agencies after creating new one
      await _loadAgencies();
      // Select the newly created agency
      setState(() {
        _currentValue = result;
      });
      widget.onChanged?.call(result);
    }
  }

  List<String> _getValidAgencyIds() {
    return _agencies.map((agency) => agency.id!).where((id) => id.isNotEmpty).toList();
  }

  String? _getSafeDropdownValue() {
    final validIds = _getValidAgencyIds();
    if (_currentValue != null && validIds.contains(_currentValue)) {
      return _currentValue;
    }
    return null;
  }

  List<DropdownMenuItem<String>> _buildSafeDropdownItems() {
    final items = <DropdownMenuItem<String>>[];
    
    for (final agency in _agencies) {
      if (agency.id != null && agency.id!.isNotEmpty) {
        items.add(
          DropdownMenuItem<String>(
            value: agency.id!,
            child: Text(
              agency.name,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }
    
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.labelText! + (widget.isRequired ? ' *' : ''),
              style: AppTheme.labelLarge,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _isLoading
                  ? Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[600]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[900],
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldColor),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[600]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[900],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _getSafeDropdownValue(),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        hint: Text(
                          widget.hintText ?? 'Select an agency',
                          style: TextStyle(color: Colors.grey[400]),
                          overflow: TextOverflow.ellipsis,
                        ),
                        isExpanded: true,
                        items: _buildSafeDropdownItems(),
                        onChanged: widget.enabled ? _handleDropdownChange : null,
                        validator: widget.validator,
                      ),
                    ),
            ),
            if (widget.showAddButton) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _createNewAgency,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  minimumSize: const Size(60, 56),
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _handleDropdownChange(String? value) {
    debugPrint('AgencyDropdown: Handling dropdown change to: $value');

    setState(() {
      _currentValue = value;
    });
    widget.onChanged?.call(value);
  }
}
