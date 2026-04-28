import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order_model.dart';
import '../models/vehicle_model.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Admin/Accounts: edit invoice and toll per segment (server rejects when order is terminal).
class OrderAdminSegmentPricingDialog extends StatefulWidget {
  final OrderModel order;
  final String userId;
  final VoidCallback onSaved;

  const OrderAdminSegmentPricingDialog({
    super.key,
    required this.order,
    required this.userId,
    required this.onSaved,
  });

  @override
  State<OrderAdminSegmentPricingDialog> createState() => _OrderAdminSegmentPricingDialogState();
}

class _OrderAdminSegmentPricingDialogState extends State<OrderAdminSegmentPricingDialog> {
  late final List<TextEditingController> _invoiceCtrls;
  late final List<TextEditingController> _tollCtrls;

  @override
  void initState() {
    super.initState();
    _invoiceCtrls = widget.order.tripSegments.map((s) {
      final v = s.invoiceAmount ?? 0;
      return TextEditingController(text: v.toString());
    }).toList();
    _tollCtrls = widget.order.tripSegments.map((s) {
      final v = s.tollCharges ?? 0;
      return TextEditingController(text: v.toString());
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _invoiceCtrls) {
      c.dispose();
    }
    for (final c in _tollCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final segments = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.order.tripSegments.length; i++) {
      final seg = widget.order.tripSegments[i];
      final inv = int.tryParse(_invoiceCtrls[i].text.trim()) ?? 0;
      final toll = int.tryParse(_tollCtrls[i].text.trim()) ?? 0;
      segments.add({
        'segment_id': seg.segmentId,
        'invoice_amount': inv,
        'toll_charges': toll,
      });
    }

    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<OrderProvider>(context, listen: false);

    final result = await provider.updateOrderSegmentPricing(
      orderId: widget.order.orderId,
      userId: widget.userId,
      segments: segments,
    );

    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );

    if (result['success'] == true) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit segment pricing'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.order.tripSegments.length, (i) {
              final seg = widget.order.tripSegments[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Segment ${seg.segmentId}: ${seg.source} → ${seg.destination}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _invoiceCtrls[i],
                            decoration: const InputDecoration(
                              labelText: 'Invoice (₹)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _tollCtrls[i],
                            decoration: const InputDecoration(
                              labelText: 'Toll (₹)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Vehicle picker + manual entry (same UX as order approval / dashboard).
class OrderVehicleSelectionDialog extends StatefulWidget {
  final OrderModel order;
  final int totalWeight;
  final ApiService apiService;

  const OrderVehicleSelectionDialog({
    super.key,
    required this.order,
    required this.totalWeight,
    required this.apiService,
  });

  @override
  State<OrderVehicleSelectionDialog> createState() => _OrderVehicleSelectionDialogState();
}

class _OrderVehicleSelectionDialogState extends State<OrderVehicleSelectionDialog> {
  List<VehicleModel> _matchedVehicles = [];
  VehicleModel? _selectedVehicle;
  bool _showManualVehicleEntry = false;
  bool _isMatchingVehicles = false;

  final _manualVehicleNumberController = TextEditingController();
  final _manualVehicleTypeController = TextEditingController();
  final _manualCapacityController = TextEditingController();
  String? _manualVehicleType;

  final List<String> _vehicleTypeOptions = ['Open', 'Closed', 'Container'];

  @override
  void initState() {
    super.initState();
    _matchVehicles();
  }

  @override
  void dispose() {
    _manualVehicleNumberController.dispose();
    _manualVehicleTypeController.dispose();
    _manualCapacityController.dispose();
    super.dispose();
  }

  Future<void> _matchVehicles() async {
    setState(() {
      _isMatchingVehicles = true;
      _showManualVehicleEntry = false;
    });

    try {
      final result = await widget.apiService.matchVehicles(widget.totalWeight);
      if (result['success'] == true) {
        setState(() {
          _matchedVehicles = result['vehicles'] as List<VehicleModel>;
          _selectedVehicle = null;
          if (_matchedVehicles.isEmpty) {
            _showManualVehicleEntry = true;
          }
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isMatchingVehicles = false;
      });
    }
  }

  void _handleConfirm() {
    if (_selectedVehicle != null) {
      Navigator.of(context).pop(_selectedVehicle);
    } else if (_showManualVehicleEntry) {
      if (_manualVehicleNumberController.text.trim().isEmpty ||
          _manualVehicleType == null ||
          _manualCapacityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete all manual vehicle entry fields'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final manualVehicle = VehicleModel(
        vehicleId: '',
        vehicleNumber: _manualVehicleNumberController.text.trim(),
        type: _manualVehicleType!,
        capacityKg: int.tryParse(_manualCapacityController.text.trim()) ?? 0,
        vehicleType: _manualVehicleType!,
        vendorVehicle: 'manual_entry',
        isBusy: false,
      );
      Navigator.of(context).pop(manualVehicle);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle or use manual entry'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assign Vehicle to Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Order ${widget.order.orderId} - Total Weight: ${widget.totalWeight} kg',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (_isMatchingVehicles)
                  const Center(child: CircularProgressIndicator())
                else if (_matchedVehicles.isEmpty && !_showManualVehicleEntry)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'No suitable vehicles found',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use the "Add Manual Truck Entry" button below.',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...(_matchedVehicles.map((vehicle) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildVehicleCard(vehicle),
                      ))),
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.orange),
                    title: const Text('Add Manual Truck Entry'),
                    onTap: () {
                      setState(() {
                        _showManualVehicleEntry = !_showManualVehicleEntry;
                        if (_showManualVehicleEntry) {
                          _selectedVehicle = null;
                        }
                      });
                    },
                  ),
                ),
                if (_showManualVehicleEntry) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualVehicleNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _manualVehicleType,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _vehicleTypeOptions.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _manualVehicleType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualCapacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacity (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Assign & Continue'),
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

  Widget _buildVehicleCard(VehicleModel vehicle) {
    final isSelected = _selectedVehicle?.vehicleId == vehicle.vehicleId;
    final isOptimal = vehicle.utilizationPercentage != null &&
        vehicle.utilizationPercentage! >= 80 &&
        vehicle.utilizationPercentage! <= 100;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryOrange
              : (isOptimal ? Colors.green : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedVehicle = vehicle;
            _showManualVehicleEntry = false;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    vehicle.vehicleNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primaryOrange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Type: ${vehicle.vehicleType.isNotEmpty ? vehicle.vehicleType : vehicle.type}',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Capacity: ${vehicle.capacityKg} kg',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
              if (vehicle.utilizationPercentage != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Utilization: ${vehicle.utilizationPercentage!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isOptimal ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
