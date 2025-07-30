import 'package:flutter/material.dart';
import 'input.dart';

/// Helper class to manage form field navigation with next buttons
class FormNavigationHelper {
  final List<FocusNode> _focusNodes = [];
  int _currentIndex = 0;

  /// Add a focus node to the navigation chain
  FocusNode addField() {
    final focusNode = FocusNode();
    _focusNodes.add(focusNode);
    return focusNode;
  }

  /// Move to the next field in the chain
  void nextField() {
    if (_currentIndex < _focusNodes.length - 1) {
      _currentIndex++;
      _focusNodes[_currentIndex].requestFocus();
    } else {
      // If we're at the last field, unfocus to hide keyboard
      _focusNodes[_currentIndex].unfocus();
    }
  }

  /// Move to the previous field in the chain
  void previousField() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _focusNodes[_currentIndex].requestFocus();
    }
  }

  /// Focus on a specific field by index
  void focusField(int index) {
    if (index >= 0 && index < _focusNodes.length) {
      _currentIndex = index;
      _focusNodes[index].requestFocus();
    }
  }

  /// Check if this is the last field
  bool isLastField(FocusNode focusNode) {
    final index = _focusNodes.indexOf(focusNode);
    return index == _focusNodes.length - 1;
  }

  /// Get the appropriate next button text
  String getNextButtonText(FocusNode focusNode) {
    return isLastField(focusNode) ? 'Done' : 'Next';
  }

  /// Handle next button press for a specific field
  void handleNext(FocusNode focusNode) {
    final index = _focusNodes.indexOf(focusNode);
    if (index != -1) {
      _currentIndex = index;
      nextField();
    }
  }

  /// Dispose all focus nodes
  void dispose() {
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _focusNodes.clear();
  }

  /// Get the current field index
  int get currentIndex => _currentIndex;

  /// Get the total number of fields
  int get fieldCount => _focusNodes.length;

  /// Check if navigation is available
  bool get hasNavigation => _focusNodes.isNotEmpty;
}

/// Extension to make it easier to use with Input widgets
extension FormNavigationInput on FormNavigationHelper {
  /// Create an Input widget with automatic next field navigation
  Widget createInputField({
    String? label,
    String? placeholder,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? prefix,
    Widget? suffix,
    int? maxLines = 1,
    bool autofocus = false,
    bool enabled = true,
    Widget? prefixIcon,
    String? hintText,
    bool showPasswordToggle = false,
    bool enableNextButton = true,
  }) {
    final focusNode = addField();

    return Input(
      label: label,
      placeholder: placeholder,
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      prefix: prefix,
      suffix: suffix,
      maxLines: maxLines,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      prefixIcon: prefixIcon,
      hintText: hintText,
      showPasswordToggle: showPasswordToggle,
      showNextButton: enableNextButton,
      onNext: enableNextButton ? () => handleNext(focusNode) : null,
      nextButtonText: enableNextButton ? getNextButtonText(focusNode) : null,
      textInputAction:
          isLastField(focusNode) ? TextInputAction.done : TextInputAction.next,
    );
  }
}
