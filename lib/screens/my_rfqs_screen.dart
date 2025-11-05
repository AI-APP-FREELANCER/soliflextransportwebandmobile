import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rfq_provider.dart';
import '../models/rfq_model.dart';

class MyRFQsScreen extends StatefulWidget {
  const MyRFQsScreen({super.key});

  @override
  State<MyRFQsScreen> createState() => _MyRFQsScreenState();
}

class _MyRFQsScreenState extends State<MyRFQsScreen> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRFQs();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload if we have a route result (e.g., after creating new RFQ)
    // This prevents unnecessary reloads
  }

  Future<void> _loadRFQs() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      await Provider.of<RFQProvider>(context, listen: false).loadUserRFQs(user.userId);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING_APPROVAL':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.grey;
      case 'MODIFICATION_PENDING':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  List<RFQModel> _getFilteredRFQs(List<RFQModel> rfqs) {
    if (_selectedFilter == 'All') {
      return rfqs;
    }
    return rfqs.where((rfq) => rfq.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My RFQs'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  'All',
                  'PENDING_APPROVAL',
                  'APPROVED',
                  'REJECTED',
                  'IN_PROGRESS',
                  'COMPLETED'
                ].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        filter == 'All' ? 'All' : filter.replaceAll('_', ' '),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: const Color(0xFFFF6600),
                      checkmarkColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
            // RFQ List
            Expanded(
              child: Consumer<RFQProvider>(
                builder: (context, rfqProvider, child) {
                  if (rfqProvider.isLoading && rfqProvider.rfqs.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (rfqProvider.error != null && rfqProvider.rfqs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              rfqProvider.error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _loadRFQs(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6600),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredRFQs = _getFilteredRFQs(rfqProvider.rfqs);

                  if (filteredRFQs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No RFQs found',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFilter == 'All' 
                                ? 'Create your first RFQ to get started'
                                : 'No RFQs match the selected filter',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadRFQs,
                    color: const Color(0xFFFF6600),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: filteredRFQs.length,
                      itemBuilder: (context, index) {
                        final rfq = filteredRFQs[index];
                        return _buildRFQCard(rfq);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to RFQ creation screen
          final result = await Navigator.of(context).pushNamed('/rfq/create');
          // Reload RFQs when returning from creation screen
          if (mounted) {
            await _loadRFQs();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create RFQ'),
        backgroundColor: const Color(0xFFFF6600),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildRFQCard(RFQModel rfq) {
    final statusColor = _getStatusColor(rfq.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RFQ #${rfq.rfqId}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rfq.source} → ${rfq.destination}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    rfq.statusDisplay,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(Icons.scale, 'Weight', '${rfq.materialWeight} kg'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(Icons.category, 'Type', rfq.materialType),
                ),
              ],
            ),
            if (rfq.vehicleNumber != null && rfq.vehicleNumber!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(Icons.local_shipping, 'Vehicle', rfq.vehicleNumber!),
                  ),
                ],
              ),
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
                    _formatDate(rfq.createdAt!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
              ],
            ),
            if (rfq.rejectionReason != null && rfq.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rejection Reason: ${rfq.rejectionReason}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            mainAxisSize: MainAxisSize.min,
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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

