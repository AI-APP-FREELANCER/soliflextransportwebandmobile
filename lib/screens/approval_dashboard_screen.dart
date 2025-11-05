import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rfq_provider.dart';
import '../models/rfq_model.dart';

class ApprovalDashboardScreen extends StatefulWidget {
  const ApprovalDashboardScreen({super.key});

  @override
  State<ApprovalDashboardScreen> createState() => _ApprovalDashboardScreenState();
}

class _ApprovalDashboardScreenState extends State<ApprovalDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RFQProvider>(context, listen: false).loadPendingRFQs();
    });
  }

  void _showRejectDialog(RFQModel rfq) {
    final rejectionReasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject RFQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RFQ #${rfq.rfqId}'),
            const SizedBox(height: 16),
            TextField(
              controller: rejectionReasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'Enter reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (rejectionReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final rfqProvider = Provider.of<RFQProvider>(context, listen: false);
              final user = authProvider.user;

              if (user == null) return;

              final success = await rfqProvider.rejectRFQ(
                rfq.rfqId,
                user.userId,
                rejectionReasonController.text.trim(),
              );

              if (context.mounted) {
                Navigator.of(context).pop();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('RFQ rejected successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(rfqProvider.error ?? 'Failed to reject RFQ'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRFQ(RFQModel rfq) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final rfqProvider = Provider.of<RFQProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) return;

    final success = await rfqProvider.approveRFQ(rfq.rfqId, user.userId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('RFQ approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rfqProvider.error ?? 'Failed to approve RFQ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soliflex Packaging - Pending Approvals'),
      ),
      body: SafeArea(
        child: Consumer<RFQProvider>(
          builder: (context, rfqProvider, child) {
            if (rfqProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (rfqProvider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      rfqProvider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            }

            if (rfqProvider.pendingRFQs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Pending Approvals',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All RFQs have been reviewed',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await rfqProvider.loadPendingRFQs();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: rfqProvider.pendingRFQs.length,
                itemBuilder: (context, index) {
                  final rfq = rfqProvider.pendingRFQs[index];
                  return _buildRFQApprovalCard(rfq);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRFQApprovalCard(RFQModel rfq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RFQ #${rfq.rfqId}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: const Text(
                    'Pending Approval',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${rfq.source} → ${rfq.destination}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(Icons.scale, 'Weight', '${rfq.materialWeight} kg'),
                ),
                Expanded(
                  child: _buildInfoItem(Icons.category, 'Type', rfq.materialType),
                ),
              ],
            ),
            if (rfq.vehicleNumber != null && rfq.vehicleNumber!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoItem(Icons.local_shipping, 'Vehicle', rfq.vehicleNumber!),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cost: ₹${rfq.totalCost.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF6600),
                      ),
                ),
                if (rfq.createdAt != null)
                  Text(
                    'Created: ${_formatDate(rfq.createdAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveRFQ(rfq),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(rfq),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFF6600)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

