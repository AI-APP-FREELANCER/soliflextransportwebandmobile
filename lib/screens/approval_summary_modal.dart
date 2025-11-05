import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/trip_segment_model.dart';
import '../theme/app_theme.dart';

class ApprovalSummaryModal extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onApprove;

  const ApprovalSummaryModal({
    super.key,
    required this.order,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    // Get original totals from stored values (if available) or calculate from segments
    final originalTotalWeight = order.originalTotalWeight ?? 0;
    final originalTotalInvoice = order.originalTotalInvoiceAmount ?? 0;
    final originalTotalToll = order.originalTotalTollCharges ?? 0;
    final originalSegmentCount = order.originalSegmentCount ?? order.tripSegments.length;
    
    // Calculate projected totals (after amendment) - these are the current totals
    final projectedTotalWeight = order.getTotalWeight();
    final projectedTotalInvoice = order.getTotalInvoiceAmount();
    final projectedTotalToll = order.getTotalTollCharges();
    
    // If no stored original segment count, use heuristic based on trip type
    final List<TripSegment> displayNewSegments;
    if (order.originalSegmentCount != null && order.originalSegmentCount! > 0) {
      // Use stored original segment count - identify new segments by segment_id > originalSegmentCount
      displayNewSegments = order.tripSegments.where((s) => 
        s.segmentId != null && s.segmentId! > order.originalSegmentCount!
      ).toList();
    } else if (order.originalTripType == 'Round-Trip-Vendor' && order.tripSegments.length > 2) {
      // Round Trip: Original had 2 segments, new ones are 3+
      displayNewSegments = order.tripSegments.sublist(2);
    } else {
      // For other types, show all segments (fallback)
      displayNewSegments = order.tripSegments;
    }

    // Format amendment timestamp
    String formattedAmendmentDate = 'N/A';
    if (order.amendmentRequestedAt != null) {
      final date = order.amendmentRequestedAt!;
      formattedAmendmentDate = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Identify new segments (last N segments that were added)
    // We'll identify this by segment count - for now, show all segments
    final newSegments = order.tripSegments; // All segments for display

    return Dialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amendment Approval Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Divider(color: AppTheme.darkBorder),
                const SizedBox(height: 16),

                // Order ID
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppTheme.primaryOrange, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Order ID: ${order.orderId}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Side-by-side comparison layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Original Details
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.darkBorder, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history, color: Colors.blue.shade400, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Original Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow('Total Segments', '$originalSegmentCount'),
                            _buildInfoRow('Total Weight', '${originalTotalWeight} kg'),
                            _buildInfoRow('Total Invoice', '₹$originalTotalInvoice'),
                            _buildInfoRow('Total Toll', '₹$originalTotalToll'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right Column: Amendment Details (New Segments)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.add_circle, color: Colors.orange.shade400, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Amendment Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'New Segments Added:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (displayNewSegments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'No new segments found',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ...displayNewSegments.asMap().entries.map((entry) {
                                final index = entry.key;
                                final segment = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkCard,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Segment #${segment.segmentId}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${segment.source} → ${segment.destination}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Weight: ${segment.materialWeight} kg',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (segment.invoiceAmount != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.attach_money, size: 14, color: Colors.green.shade400),
                                              const SizedBox(width: 4),
                                              Text(
                                                '₹${segment.invoiceAmount}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green.shade400,
                                                ),
                                              ),
                                              if (segment.isManualInvoice == true) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: const Text(
                                                    'M',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        if (segment.tollCharges != null && segment.tollCharges! > 0) ...[
                                          const SizedBox(width: 12),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.local_atm, size: 14, color: Colors.blue.shade400),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Toll: ₹${segment.tollCharges}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Audit Trail Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.audiotrack, color: Colors.purple.shade400, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Audit Trail Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Requested By', order.amendmentRequestedBy ?? 'N/A'),
                      _buildInfoRow('Department', order.amendmentRequestedDepartment ?? 'N/A'),
                      _buildInfoRow('Date/Time', formattedAmendmentDate),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Projected New Totals Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.5), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.green.shade400, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Projected New Totals (After Approval)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Total Segments', '${order.tripSegments.length}', Colors.green),
                      _buildInfoRow('Total Weight', '${projectedTotalWeight} kg', Colors.green),
                      _buildInfoRow('Total Invoice Amount', '₹$projectedTotalInvoice', Colors.green),
                      _buildInfoRow('Total Toll Charges', '₹$projectedTotalToll', Colors.green),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close approval summary modal
                        onApprove(); // Trigger approval
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve Amendment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

