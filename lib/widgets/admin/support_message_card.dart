import 'package:flutter/material.dart';
import '../../models/support_message.dart';
import '../../theme/app_theme.dart';

class SupportMessageCard extends StatefulWidget {
  final SupportMessage message;
  final Function(String) onStatusUpdate;
  final Function(String) onRespond;

  const SupportMessageCard({
    super.key,
    required this.message,
    required this.onStatusUpdate,
    required this.onRespond,
  });

  @override
  State<SupportMessageCard> createState() => _SupportMessageCardState();
}

class _SupportMessageCardState extends State<SupportMessageCard> {
  bool _isExpanded = false;
  final _responseController = TextEditingController();
  bool _isResponding = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Message header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Message info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              flex: 2,
                              child: Text(
                                'From: ${widget.message.userEmail}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 1,
                              child: Text(
                                _formatDate(),
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _getStatusColor().withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      widget.message.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Expand icon
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(color: AppTheme.borderColor, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content
                  const Text(
                    'Message:',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      widget.message.message,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Admin response (if exists)
                  if (widget.message.adminResponse != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Admin Response:',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                            color: AppTheme.goldColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            color: AppTheme.goldColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.message.adminResponse!,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Actions
                  if (widget.message.status == 'pending') ...[
                    if (!_isResponding) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isResponding = true;
                                });
                              },
                              icon: const Icon(Icons.reply,
                                  color: AppTheme.goldColor),
                              label: const Text(
                                'Respond',
                                style: TextStyle(color: AppTheme.goldColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: AppTheme.goldColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  widget.onStatusUpdate('resolved'),
                              icon:
                                  const Icon(Icons.check, color: Colors.black),
                              label: const Text(
                                'Mark Resolved',
                                style: TextStyle(color: Colors.black),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Response form
                      TextField(
                        controller: _responseController,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Type your response...',
                          hintStyle: const TextStyle(color: AppTheme.textMuted),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            borderSide:
                                const BorderSide(color: AppTheme.goldColor),
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _isResponding = false;
                                  _responseController.clear();
                                });
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_responseController.text
                                    .trim()
                                    .isNotEmpty) {
                                  widget.onRespond(
                                      _responseController.text.trim());
                                  setState(() {
                                    _isResponding = false;
                                    _responseController.clear();
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.goldColor,
                              ),
                              child: const Text(
                                'Send Response',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    // Status change options for resolved/closed messages
                    Row(
                      children: [
                        if (widget.message.status == 'resolved')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => widget.onStatusUpdate('closed'),
                              icon: const Icon(Icons.close,
                                  color: AppTheme.errorColor),
                              label: const Text(
                                'Close',
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppTheme.errorColor),
                              ),
                            ),
                          ),
                        if (widget.message.status != 'pending')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => widget.onStatusUpdate('pending'),
                              icon: const Icon(Icons.refresh,
                                  color: AppTheme.warningColor),
                              label: const Text(
                                'Reopen',
                                style: TextStyle(color: AppTheme.warningColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppTheme.warningColor),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.message.status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'resolved':
        return AppTheme.successColor;
      case 'closed':
        return AppTheme.textMuted;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate() {
    final now = DateTime.now();
    final difference = now.difference(widget.message.createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
