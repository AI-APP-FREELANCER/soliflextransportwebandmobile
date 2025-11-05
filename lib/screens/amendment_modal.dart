import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/vendor_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AmendmentModal extends StatefulWidget {
  final OrderModel order;
  final Function(List<Map<String, dynamic>>) onAmend;

  const AmendmentModal({
    super.key,
    required this.order,
    required this.onAmend,
  });

  @override
  State<AmendmentModal> createState() => _AmendmentModalState();
}

class _AmendmentModalState extends State<AmendmentModal> {
  final List<Map<String, dynamic>> _newSegments = [];
  final _formKey = GlobalKey<FormState>();
  final List<String> _materialTypeOptions = ['Raw Materials', 'Rolls', 'Wastage', 'Other'];
  final ApiService _apiService = ApiService();
  // Preview invoice for final return segment (Round Trip only)
  int? _finalReturnSegmentInvoice;
  int? _finalReturnSegmentToll;
  bool _isCalculatingReturnInvoice = false;
  
  @override
  void initState() {
    super.initState();
    // For Round Trip: Initialize with single empty segment (B → C)
    // For Round Trip: Source should be B (destination of segment 1, not last segment's destination)
    // For other trip types: Initialize with one empty segment from last segment's destination
    String sourceForNewSegment = '';
    if (widget.order.tripSegments.isNotEmpty) {
      if (_isRoundTrip()) {
        // For Round Trip: Source is B (destination of segment 1: A → B)
        sourceForNewSegment = widget.order.tripSegments[0].destination;
      } else {
        // For other trip types: Source is the last segment's destination
        sourceForNewSegment = widget.order.tripSegments.last.destination;
      }
    }
    _newSegments.add({
      'source': sourceForNewSegment, // For Round Trip: This is B (destination of segment 1: A→B)
      'destination': '', // For Round Trip: This will be C (Additional Route)
      'material_weight': 0,
      'material_type': '',
      'selected_material_types': <String>[],
      'other_material_text': '',
      'invoice_amount': null,
      'toll_charges': null,
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load vendors when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
      if (vendorProvider.vendors.isEmpty && !vendorProvider.isLoading) {
        await vendorProvider.loadVendors();
      }
    });
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
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amend Order',
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
                  
                  // Existing Segments (Read-only)
                  const Text(
                    'Existing Trip Segments',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFFF6600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: widget.order.tripSegments.map((segment) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: segment != widget.order.tripSegments.last
                                ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Segment #${segment.segmentId}: ${segment.source} → ${segment.destination}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${segment.materialWeight} kg',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Type: ${segment.materialTypeList.join(", ")}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  // For Round Trip: Show simplified "Additional Route" label
                  // For other trip types: Show "Add New Segments" label
                  Text(
                    _isRoundTrip() ? 'Additional Route' : 'Add New Segments',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFFF6600),
                    ),
                  ),
                  if (_isRoundTrip()) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Add a single stop to the route: ${widget.order.tripSegments.isNotEmpty ? widget.order.tripSegments[0].destination : "B"} → C',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  
                  // New Segments Builder
                  // For Round Trip: Only show single segment form
                  // For other trip types: Show all segments
                  ..._newSegments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final segment = entry.value;
                    return _buildSegmentForm(index, segment);
                  }).toList(),
                  
                  // Hide "Add Another Segment" button for Round Trip
                  if (!_isRoundTrip()) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          // Get last segment's destination as default source for new segment
                          final lastDest = _newSegments.isNotEmpty 
                              ? _newSegments.last['destination'] 
                              : (widget.order.tripSegments.isNotEmpty
                                  ? widget.order.tripSegments.last.destination
                                  : '');
                          _newSegments.add({
                            'source': lastDest,
                            'destination': '',
                            'material_weight': 0,
                            'material_type': '',
                            'selected_material_types': <String>[],
                            'other_material_text': '',
                            'invoice_amount': null,
                            'toll_charges': null,
                          });
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Segment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Part 2: Parse string state to int before submission
                            for (var segment in _newSegments) {
                              if (segment['_invoice_string'] != null) {
                                segment['invoice_amount'] = int.tryParse(segment['_invoice_string'].toString()) ?? segment['invoice_amount'];
                              }
                              if (segment['_toll_string'] != null) {
                                segment['toll_charges'] = int.tryParse(segment['_toll_string'].toString()) ?? segment['toll_charges'];
                              }
                            }
                            widget.onAmend(_newSegments);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6600),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit Amendment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Check if order is Round Trip
  bool _isRoundTrip() {
    return widget.order.tripType == 'Round-Trip-Vendor' || 
           widget.order.originalTripType == 'Round-Trip-Vendor';
  }
  
  // Calculate preview invoice for final return segment (C → A)
  Future<void> _calculateFinalReturnSegmentPreview(int weightFromModal) async {
    if (!_isRoundTrip() || _newSegments.isEmpty) return;
    
    final lastNewSegment = _newSegments.last;
    final lastDestination = lastNewSegment['destination']?.toString() ?? '';
    final orderSource = widget.order.tripSegments.isNotEmpty
        ? widget.order.tripSegments[0].source
        : widget.order.source;
    
    // Only calculate if last destination is a vendor (not the original source)
    if (lastDestination.isNotEmpty && 
        lastDestination != orderSource && 
        weightFromModal > 0) {
      setState(() {
        _isCalculatingReturnInvoice = true;
      });
      
      try {
        // Calculate invoice using drop rates (source is vendor location)
        final result = await _apiService.calculateInvoiceRate(
          sourceLocation: lastDestination, // Vendor location (source for return segment)
          materialWeight: weightFromModal, // Weight from amendment modal
        );
        
        if (mounted) {
          setState(() {
            _finalReturnSegmentInvoice = result['invoice_amount'] ?? 0;
            _finalReturnSegmentToll = result['toll_charges'] ?? 0;
            _isCalculatingReturnInvoice = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _finalReturnSegmentInvoice = null;
            _finalReturnSegmentToll = null;
            _isCalculatingReturnInvoice = false;
          });
        }
      }
    }
  }

  Widget _buildSegmentForm(
    int index,
    Map<String, dynamic> segment,
  ) {

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // For Round Trip: Show simplified label
          // For other trip types: Show segment number
          Text(
            _isRoundTrip() 
                ? 'Additional Route (B → C)'
                : 'New Segment #${widget.order.tripSegments.length + index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          
          // For Round Trip: Hide Source dropdown (source is always B, set automatically)
          // For other trip types: Show Source dropdown
          if (!_isRoundTrip()) ...[
            Consumer<VendorProvider>(
              builder: (context, vendorProvider, child) {
                if (vendorProvider.isLoading && vendorProvider.vendors.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (vendorProvider.error != null && vendorProvider.vendors.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Error: ${vendorProvider.error}',
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            vendorProvider.loadVendors();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final vendors = vendorProvider.vendors;
                
                if (vendors.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('No vendors found', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            vendorProvider.loadVendors();
                          },
                          child: const Text('Reload'),
                        ),
                      ],
                    ),
                  );
                }

                final currentSource = segment['source']?.toString();
                final sourceValue = currentSource != null && currentSource.isNotEmpty 
                    ? currentSource 
                    : null;

                return DropdownButtonFormField<String>(
                  value: sourceValue,
                  decoration: const InputDecoration(
                    labelText: 'Starting Point *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: vendors.map((vendor) {
                    return DropdownMenuItem<String>(
                      value: vendor.name,
                      child: Text(vendor.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _newSegments[index]['source'] = value ?? '';
                      // Reset invoice calculation to trigger recalculation
                      _newSegments[index]['invoice_amount'] = null;
                      _newSegments[index]['toll_charges'] = null;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a starting point';
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ] else ...[
            // For Round Trip: Show read-only source (B)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'From (B)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          segment['source']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Destination Dropdown
          Consumer<VendorProvider>(
            builder: (context, vendorProvider, child) {
              if (vendorProvider.isLoading && vendorProvider.vendors.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (vendorProvider.error != null && vendorProvider.vendors.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Error: ${vendorProvider.error}',
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          vendorProvider.loadVendors();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final vendors = vendorProvider.vendors;
              
              if (vendors.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('No vendors found', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          vendorProvider.loadVendors();
                        },
                        child: const Text('Reload'),
                      ),
                    ],
                  ),
                );
              }

              final currentDestination = segment['destination']?.toString();
              final destinationValue = currentDestination != null && currentDestination.isNotEmpty 
                  ? currentDestination 
                  : null;

              return DropdownButtonFormField<String>(
                value: destinationValue,
                decoration: InputDecoration(
                  labelText: _isRoundTrip() ? 'Additional Route (C) *' : 'End Point *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                items: vendors.map((vendor) {
                  return DropdownMenuItem<String>(
                    value: vendor.name,
                    child: Text(vendor.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _newSegments[index]['destination'] = value ?? '';
                  });
                  // For Round Trip: Recalculate final return segment preview when destination changes
                  if (_isRoundTrip() && index == _newSegments.length - 1) {
                    final weight = int.tryParse(segment['material_weight']?.toString() ?? '0') ?? 0;
                    if (weight > 0 && value != null && value.isNotEmpty) {
                      _calculateFinalReturnSegmentPreview(weight);
                    }
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an end point';
                  }
                  return null;
                },
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Material Weight
          TextFormField(
            initialValue: segment['material_weight']?.toString() ?? '0',
            decoration: const InputDecoration(
              labelText: 'Material Weight (kg) *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final weight = int.tryParse(value) ?? 0;
              setState(() {
                _newSegments[index]['material_weight'] = weight;
                // Reset invoice calculation to trigger recalculation
                _newSegments[index]['invoice_amount'] = null;
                _newSegments[index]['toll_charges'] = null;
              });
              // For Round Trip: Calculate final return segment preview when weight changes
              if (_isRoundTrip() && index == _newSegments.length - 1 && weight > 0) {
                _calculateFinalReturnSegmentPreview(weight);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter material weight';
              }
              if (int.tryParse(value) == null || int.parse(value) <= 0) {
                return 'Please enter a valid weight';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 12),
          
          // Material Type Multi-Select
          FormField<List<String>>(
            initialValue: (segment['selected_material_types'] as List<String>?) ?? [],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select at least one material type';
              }
              if (value.contains('Other') && 
                  (segment['other_material_text']?.toString() ?? '').trim().isEmpty) {
                return 'Please enter material name for "Other"';
              }
              return null;
            },
            builder: (field) {
              List<String> selectedTypes = (segment['selected_material_types'] as List<String>?) ?? [];
              String otherText = (segment['other_material_text']?.toString() ?? '') ?? '';
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Material Type *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _materialTypeOptions.map((option) {
                      final isSelected = selectedTypes.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (!selectedTypes.contains(option)) {
                                selectedTypes.add(option);
                              }
                            } else {
                              selectedTypes.remove(option);
                              if (option == 'Other') {
                                otherText = '';
                                segment['other_material_text'] = '';
                              }
                            }
                            segment['selected_material_types'] = selectedTypes;
                            // Format as JSON array for storage
                            List<String> materialTypeList = [];
                            for (String type in selectedTypes) {
                              if (type == 'Other' && otherText.isNotEmpty) {
                                materialTypeList.add('Other: $otherText');
                              } else if (type != 'Other') {
                                materialTypeList.add(type);
                              }
                            }
                            segment['material_type'] = jsonEncode(materialTypeList);
                            field.didChange(selectedTypes);
                          });
                        },
                        selectedColor: const Color(0xFFFF6600).withOpacity(0.3),
                        checkmarkColor: const Color(0xFFFF6600),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFFFF6600) : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedTypes.contains('Other')) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: otherText,
                      decoration: const InputDecoration(
                        labelText: 'Other Material Name *',
                        hintText: 'Enter material name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          segment['other_material_text'] = value;
                          // Reformat material type JSON
                          List<String> materialTypeList = [];
                          for (String type in selectedTypes) {
                            if (type == 'Other' && value.isNotEmpty) {
                              materialTypeList.add('Other: $value');
                            } else if (type != 'Other') {
                              materialTypeList.add(type);
                            }
                          }
                          segment['material_type'] = jsonEncode(materialTypeList);
                        });
                      },
                    ),
                  ],
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        field.errorText ?? '',
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Invoice Amount and Toll Charges for this segment
          Builder(
            builder: (context) {
              final source = segment['source']?.toString() ?? '';
              final weight = int.tryParse(segment['material_weight']?.toString() ?? '0') ?? 0;
              final invoiceAmount = segment['invoice_amount'] as int?;
              final tollCharges = segment['toll_charges'] as int?;
              
              // Calculate invoice if source and weight are valid
              if (source.isNotEmpty && weight > 0 && (invoiceAmount == null || tollCharges == null)) {
                _apiService.calculateInvoiceRate(
                  sourceLocation: source,
                  materialWeight: weight,
                ).then((result) {
                  if (mounted) {
                    setState(() {
                      // Part 2: Update both numeric and string state
                      final invoiceValue = result['invoice_amount'] ?? 0;
                      final tollValue = result['toll_charges'] ?? 0;
                      segment['invoice_amount'] = invoiceValue;
                      segment['toll_charges'] = tollValue;
                      segment['_invoice_string'] = invoiceValue.toString();
                      segment['_toll_string'] = tollValue.toString();
                    });
                    // For Round Trip: Calculate final return segment preview
                    if (_isRoundTrip() && index == _newSegments.length - 1) {
                      _calculateFinalReturnSegmentPreview(weight);
                    }
                  }
                });
              }
              
              if (invoiceAmount != null || tollCharges != null) {
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: (segment['_invoice_string'] as String?) ?? (invoiceAmount ?? 0).toString(),
                        ),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Amount',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          // Part 2: Update string state first (allows multi-digit input)
                          setState(() {
                            segment['_invoice_string'] = value;
                            // DO NOT parse to int here - only update string state
                          });
                        },
                        onEditingComplete: () {
                          // Part 2: Parse to int only when user finishes editing
                          setState(() {
                            final stringValue = segment['_invoice_string'] as String? ?? '';
                            segment['invoice_amount'] = int.tryParse(stringValue) ?? 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: (segment['_toll_string'] as String?) ?? (tollCharges ?? 0).toString(),
                        ),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Toll Charges',
                          prefixIcon: Icon(Icons.local_atm),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          // Part 2: Update string state first (allows multi-digit input)
                          setState(() {
                            segment['_toll_string'] = value;
                            // DO NOT parse to int here - only update string state
                          });
                        },
                        onEditingComplete: () {
                          // Part 2: Parse to int only when user finishes editing
                          setState(() {
                            final stringValue = segment['_toll_string'] as String? ?? '';
                            segment['toll_charges'] = int.tryParse(stringValue) ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Final Return Segment Preview (Round Trip only) - show after last new segment
          if (_isRoundTrip() && index == _newSegments.length - 1) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final lastNewSegment = _newSegments.last;
                final lastDestination = lastNewSegment['destination']?.toString() ?? '';
                final orderSource = widget.order.tripSegments.isNotEmpty
                    ? widget.order.tripSegments[0].source
                    : widget.order.source;
                
                if (lastDestination.isNotEmpty && lastDestination != orderSource) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Final Return Segment Preview (Not Stored)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Route: $lastDestination → $orderSource',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        if (_isCalculatingReturnInvoice)
                          const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Calculating...', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          )
                        else if (_finalReturnSegmentInvoice != null)
                          Text(
                            'Preview Invoice: ₹${_finalReturnSegmentInvoice} '
                            '${_finalReturnSegmentToll != null && _finalReturnSegmentToll! > 0 ? "(Toll: ₹${_finalReturnSegmentToll})" : ""}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'Note: Backend will reset this segment to 0 kg and ₹0',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          
          if (_newSegments.length > 1) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _newSegments.removeAt(index);
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

