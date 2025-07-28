import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that makes contact information clickable with appropriate actions
class ClickableContactInfo extends StatelessWidget {
  final String text;
  final ContactType type;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;
  final double? fontSize;
  final bool showIcon;
  final TextStyle? textStyle;
  final EdgeInsets? padding;

  const ClickableContactInfo({
    super.key,
    required this.text,
    required this.type,
    this.icon,
    this.iconColor,
    this.textColor,
    this.fontSize,
    this.showIcon = true,
    this.textStyle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final defaultIconColor = iconColor ?? Colors.blue[600];
    final defaultTextColor = textColor ?? Colors.blue[600];
    
    return InkWell(
      onTap: () => _handleTap(context),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                icon ?? _getDefaultIcon(),
                size: fontSize ?? 16,
                color: defaultIconColor,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                style: textStyle ?? TextStyle(
                  color: defaultTextColor,
                  fontSize: fontSize ?? 14,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDefaultIcon() {
    switch (type) {
      case ContactType.phone:
        return Icons.chat_outlined; // Changed to chat icon since it opens WhatsApp
      case ContactType.whatsapp:
        return Icons.chat_outlined;
      case ContactType.email:
        return Icons.mail_outline;
      case ContactType.instagram:
        return Icons.camera_alt_outlined;
      case ContactType.location:
        return Icons.location_on_outlined;
      case ContactType.address:
        return Icons.home_outlined;
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    try {
      final url = _buildUrl();
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          final actionName = type == ContactType.phone ? 'WhatsApp' : type.name;
          _showErrorSnackBar(context, 'Could not open $actionName');
        }
      }
    } catch (e) {
      if (context.mounted) {
        final actionName = type == ContactType.phone ? 'WhatsApp' : type.name;
        _showErrorSnackBar(context, 'Error opening $actionName: $e');
      }
    }
  }

  String _buildUrl() {
    switch (type) {
      case ContactType.phone:
        return 'https://wa.me/${_cleanPhoneNumber(text)}';
      case ContactType.whatsapp:
        return 'https://wa.me/${_cleanPhoneNumber(text)}';
      case ContactType.email:
        return 'mailto:$text';
      case ContactType.instagram:
        return 'https://instagram.com/${_cleanInstagramHandle(text)}';
      case ContactType.location:
      case ContactType.address:
        return 'https://maps.google.com/?q=${Uri.encodeComponent(text)}';
    }
  }

  String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  String _cleanInstagramHandle(String handle) {
    // Remove @ symbol if present and any spaces
    return handle.replaceAll('@', '').replaceAll(' ', '');
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Enum for different types of contact information
enum ContactType {
  phone,
  whatsapp,
  email,
  instagram,
  location,
  address,
}

/// A widget that automatically detects and makes contact information clickable
class AutoClickableText extends StatelessWidget {
  final String text;
  final String? label;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;
  final double? fontSize;
  final bool showIcon;
  final TextStyle? textStyle;
  final EdgeInsets? padding;

  const AutoClickableText({
    super.key,
    required this.text,
    this.label,
    this.icon,
    this.iconColor,
    this.textColor,
    this.fontSize,
    this.showIcon = true,
    this.textStyle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final contactType = _detectContactType(text);
    
    if (contactType != null) {
      return ClickableContactInfo(
        text: text,
        type: contactType,
        icon: icon,
        iconColor: iconColor,
        textColor: textColor,
        fontSize: fontSize,
        showIcon: showIcon,
        textStyle: textStyle,
        padding: padding,
      );
    }

    // If no contact type detected, show as regular text
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) ...[
            Icon(
              icon,
              size: fontSize ?? 16,
              color: iconColor ?? Colors.grey,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label != null ? '$label: $text' : text,
              style: textStyle ?? TextStyle(
                color: textColor ?? Colors.grey[700],
                fontSize: fontSize ?? 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  ContactType? _detectContactType(String text) {
    // Email detection
    if (RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)) {
      return ContactType.email;
    }
    
    // Phone number detection (basic)
    if (RegExp(r'^[\+]?[\d\s\-\(\)]{7,}$').hasMatch(text)) {
      return ContactType.phone;
    }
    
    // Instagram handle detection
    if (text.startsWith('@') || text.toLowerCase().contains('instagram')) {
      return ContactType.instagram;
    }
    
    return null;
  }
}

/// Helper widget for creating contact info rows with consistent styling
class ContactInfoRow extends StatelessWidget {
  final String text;
  final ContactType type;
  final String? label;
  final EdgeInsets? padding;

  const ContactInfoRow({
    super.key,
    required this.text,
    required this.type,
    this.label,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (label != null) ...[
            SizedBox(
              width: 80,
              child: Text(
                '$label:',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ClickableContactInfo(
              text: text,
              type: type,
              showIcon: label == null,
            ),
          ),
        ],
      ),
    );
  }
}
