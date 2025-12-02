import 'package:flutter/material.dart';
import '../models/workflow_step_model.dart';
import '../theme/app_theme.dart';

class WorkflowStageCard extends StatefulWidget {
  final WorkflowStep workflowStep;
  final String stage;
  final bool canPerformAction;
  final bool isStageActive;
  final bool isRejected;
  final bool canRevoke;
  final bool canCancel;
  final Function(String action, String? comments) onAction;

  const WorkflowStageCard({
    super.key,
    required this.workflowStep,
    required this.stage,
    required this.canPerformAction,
    required this.isStageActive,
    required this.isRejected,
    required this.canRevoke,
    required this.canCancel,
    required this.onAction,
  });

  @override
  State<WorkflowStageCard> createState() => _WorkflowStageCardState();
}

class _WorkflowStageCardState extends State<WorkflowStageCard> {
  final TextEditingController _commentsController = TextEditingController();
  bool _showComments = false;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.workflowStep.status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELED':
        return Colors.orange;
      case 'PENDING':
      default:
        return widget.isStageActive ? Colors.blue : Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.workflowStep.status) {
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'CANCELED':
        return Icons.block;
      case 'PENDING':
      default:
        return Icons.pending;
    }
  }

  String _getStageDisplayName() {
    switch (widget.stage) {
      case 'SECURITY_ENTRY':
        return 'Security Entry';
      case 'STORES_VERIFICATION':
        return 'Stores Verification';
      case 'SECURITY_EXIT':
        return 'Security Exit';
      default:
        return widget.stage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    
    // CRITICAL FIX: Move variable declaration outside widget tree (before return statement)
    final shouldShowButtons = widget.canPerformAction && widget.isStageActive && widget.workflowStep.status == 'PENDING';
    
    // CRITICAL FIX: Log button visibility decision
    print('[WorkflowStageCard] Stage: ${widget.stage}, Should Show Buttons: $shouldShowButtons');
    print('  - canPerformAction: ${widget.canPerformAction}');
    print('  - isStageActive: ${widget.isStageActive}');
    print('  - status == PENDING: ${widget.workflowStep.status == 'PENDING'}');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
      ),
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stage Header
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getStageDisplayName(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    widget.workflowStep.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Location
            if (widget.workflowStep.location.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location: ${widget.workflowStep.location}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            
            // Approved By
            if (widget.workflowStep.approvedBy != null && widget.workflowStep.approvedBy!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approved by: ${widget.workflowStep.approvedBy}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Department
            if (widget.workflowStep.department != null && widget.workflowStep.department!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.business, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Department: ${widget.workflowStep.department}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Timestamp
            if (widget.workflowStep.timestamp > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Time: ${DateTime.fromMillisecondsSinceEpoch(widget.workflowStep.timestamp).toString().substring(0, 19)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Comments
            if (widget.workflowStep.comments != null && widget.workflowStep.comments!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.workflowStep.comments!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Action Buttons - CRITICAL FIX: Show Approve/Reject buttons when user has permission and stage is active
            // Note: Buttons should be visible even if comments field is not shown initially
            // CRITICAL FIX: Use the variable declared before the return statement
            if (shouldShowButtons)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Comments Field (optional - shown when user clicks "Add Comment")
                    if (_showComments) ...[
                      TextField(
                        controller: _commentsController,
                        decoration: InputDecoration(
                          labelText: 'Comments (optional for Approve, required for Reject)',
                          hintText: 'Enter comments...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                        ),
                        style: TextStyle(color: AppTheme.textPrimary),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // CRITICAL FIX: Always show Approve/Reject buttons when stage is active and user has permission
                    // Approve/Reject Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.onAction('APPROVE', _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim());
                              _commentsController.clear();
                              setState(() {
                                _showComments = false;
                              });
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // CRITICAL FIX: Require comments for rejection
                              if (_commentsController.text.trim().isEmpty) {
                                // Show comments field if not already shown
                                if (!_showComments) {
                                  setState(() {
                                    _showComments = true;
                                  });
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Comments are required for rejection. Please add a comment above.'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }
                              widget.onAction('REJECT', _commentsController.text.trim());
                              _commentsController.clear();
                              setState(() {
                                _showComments = false;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Add Comment Button (shown when comments field is hidden)
                    if (!_showComments)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showComments = true;
                            });
                          },
                          icon: const Icon(Icons.comment, size: 18),
                          label: const Text('Add Comment (Optional)'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            
            // Revoke Button
            if (widget.isRejected && widget.canRevoke)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.onAction('REVOKE', null);
                    },
                    icon: const Icon(Icons.undo),
                    label: const Text('Revoke Rejection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            
            // Cancel Button
            if (widget.canCancel && widget.workflowStep.status == 'PENDING')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: Tooltip(
                    message: widget.canCancel 
                        ? 'Cancel this order at this stage'
                        : 'Order cannot be cancelled after all approval stages have been completed',
                    child: ElevatedButton.icon(
                      onPressed: widget.canCancel ? () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Cancel Order'),
                            content: const Text('Are you sure you want to cancel this order?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('No'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onAction('CANCEL', 'Order canceled by admin');
                                },
                                child: const Text('Yes'),
                              ),
                            ],
                          ),
                        );
                      } : null,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel order at this stage'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.canCancel ? Colors.red.shade900 : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

