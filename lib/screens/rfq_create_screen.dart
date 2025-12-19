import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/rfq_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../models/vehicle_model.dart';
import '../models/vendor_model.dart'; // CRITICAL FIX: Import VendorModel for type checking
import '../theme/app_theme.dart';

class RFQCreateScreen extends StatefulWidget {
  const RFQCreateScreen({super.key});

  @override
  State<RFQCreateScreen> createState() => _RFQCreateScreenState();
}

class _RFQCreateScreenState extends State<RFQCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sourceController = TextEditingController();
  final _materialWeightController = TextEditingController();
  final _materialTypeController = TextEditingController();
  final _otherMaterialTypeController = TextEditingController();
  
  // Manual vehicle entry
  final _manualVehicleNumberController = TextEditingController();
  final _manualVehicleTypeController = TextEditingController();
  final _manualCapacityController = TextEditingController();
  
  String? _selectedSource;
  String? _selectedDestination;
  List<VehicleModel> _matchedVehicles = [];
  VehicleModel? _selectedVehicle;
  bool _showManualVehicleEntry = false;
  String? _manualVehicleType;
  bool _isMatchingVehicles = false;
  
  // Trip type selection
  String _selectedTripType = 'Single-Trip-Vendor'; // Single-Trip-Vendor, Round-Trip-Vendor, Multiple-Trip-Vendor
  
  // Multiple trip segments
  List<Map<String, dynamic>> _multipleSegments = [];
  
  // Multiple vehicle support for Multiple Trip
  List<Map<String, dynamic>> _vehicleAssignments = []; // List of vehicle assignments for Multiple Trip
  // Each assignment: {vehicleId, vehicleNumber, vehicleType, capacityKg, segmentIds: List<int>, assignedWeightKg}
  // Track which segments are assigned to which vehicle
  Map<int, int> _segmentToVehicleMap = {}; // segment index -> vehicle assignment index
  
  // Material type multi-select
  List<String> _selectedMaterialTypes = [];
  final List<String> _materialTypeOptions = ['Raw Materials', 'Rolls', 'Wastage', 'Other'];
  
  // Invoice calculation
  int? _invoiceAmount;
  int? _tollCharges;
  bool _isCalculatingInvoice = false;
  final _invoiceAmountController = TextEditingController();
  final _tollChargesController = TextEditingController();
  // Part 2: String state for manual input (prevents single-digit bug)
  String _manualInvoiceAmountString = '';
  String _manualTollChargesString = '';
  int? _autoCalculatedInvoice; // Store auto-calculated value for comparison
  int? _autoCalculatedToll; // Store auto-calculated value for comparison

  // Factory locations list (must match backend)
  static const List<String> _factoryLocations = [
    'IAF unit-1',
    'IAF unit-2',
    'IAF unit-3',
    'IAF unit-4',
    'Soliflex unit-1',
    'Soliflex unit-2',
    'Soliflex unit-3',
    'Soliflex unit-4'
  ];

  // Helper function to check if a location is a factory
  bool _isFactoryLocation(String? location) {
    if (location == null || location.isEmpty) return false;
    return _factoryLocations.any((factory) => 
      factory.toLowerCase() == location.trim().toLowerCase()
    );
  }

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    
    // Listen to material weight changes
    _materialWeightController.addListener(_onMaterialWeightChanged);
    
    // CRITICAL FIX: Validate rate card on screen initialization
    _validateRateCard();
  }
  
  // CRITICAL FIX: Validate rate card is loaded and accessible
  Future<void> _validateRateCard() async {
    try {
      // Test rate card by fetching vendors (which includes pricing data)
      final response = await _apiService.getVendors();
      
      // CRITICAL FIX: getVendors returns Map<String, dynamic> with 'vendors' key containing List<VendorModel>
      if (response['success'] == true && response['vendors'] != null) {
        final vendorsList = response['vendors'] as List<dynamic>? ?? [];
        
        if (vendorsList.isNotEmpty) {
          print('[RFQ Create] ✅ SUCCESS: Rate card loaded and accessible');
          print('[RFQ Create]   Rate card records count: ${vendorsList.length}');
          
          // CRITICAL FIX: Extract vendor names from VendorModel objects
          final sampleVendors = vendorsList.take(3).map((v) {
            // v is a VendorModel object, access its name property
            if (v is VendorModel) {
              return v.name;
            } else if (v is Map<String, dynamic>) {
              return v['name'] ?? v['vendor_name'] ?? 'N/A';
            }
            return 'N/A';
          }).join(', ');
          
          print('[RFQ Create]   Sample vendors: $sampleVendors');
        } else {
          print('[RFQ Create] ❌ FAILURE: Rate card is empty (no vendors found)');
        }
      } else {
        print('[RFQ Create] ❌ FAILURE: Rate card not accessible (API error)');
      }
    } catch (e) {
      print('[RFQ Create] ❌ FAILURE: Error loading rate card: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load vendors when screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
      // Always try to load vendors
      await vendorProvider.loadVendors();
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _materialWeightController.dispose();
    _materialTypeController.dispose();
    _otherMaterialTypeController.dispose();
    _manualVehicleNumberController.dispose();
    _manualVehicleTypeController.dispose();
    _manualCapacityController.dispose();
    _invoiceAmountController.dispose();
    _tollChargesController.dispose();
    _materialWeightController.removeListener(_onMaterialWeightChanged);
    super.dispose();
  }

  void _onMaterialWeightChanged() {
    final weight = int.tryParse(_materialWeightController.text);
    if (weight != null && weight > 0) {
      _matchVehicles(weight);
      _calculateInvoiceRate(); // Calculate invoice when weight changes
    } else {
      setState(() {
        _matchedVehicles = [];
        _selectedVehicle = null;
        _invoiceAmount = null;
        _tollCharges = null;
      });
    }
  }

  // Calculate total cumulative weight from Multiple Trip segments
  int _calculateMultipleTripTotalWeight() {
    int totalWeight = 0;
    for (var segment in _multipleSegments) {
      final weight = int.tryParse(segment['material_weight']?.toString() ?? '0') ?? 0;
      totalWeight += weight;
    }
    return totalWeight;
  }

  // Trigger vehicle matching for Multiple Trip when segments have weights
  void _onMultipleTripWeightChanged() {
    if (_selectedTripType == 'Multiple-Trip-Vendor') {
      final totalWeight = _calculateMultipleTripTotalWeight();
      if (totalWeight > 0) {
        print('[RFQ Create] Multiple Trip total weight: $totalWeight kg, triggering vehicle matching...');
        _matchVehicles(totalWeight);
      } else {
        setState(() {
          _matchedVehicles = [];
          _selectedVehicle = null;
        });
      }
    }
  }
  
  // Calculate invoice rate for a segment (used in Multiple Trip form)
  // USER REQUEST: For Multiple Trip, ALWAYS use Drop rates for all segments
  Future<Map<String, dynamic>> _calculateSegmentInvoice(String source, int weight, String? destination) async {
    if (source.isEmpty || weight <= 0) {
      return {'invoice_amount': 0, 'toll_charges': 0};
    }
    
    try {
      // USER REQUEST: For Multiple Trip, pass tripType to force Drop rates
      // The backend will use Drop rates (dropped_by_vendor_*) columns for all Multiple Trip segments
      final result = await _apiService.calculateInvoiceRate(
        sourceLocation: source,
        materialWeight: weight,
        destinationLocation: destination, // Pass destination for segment calculation
        tripType: _selectedTripType == 'Multiple-Trip-Vendor' ? 'Multiple-Trip-Vendor' : null, // USER REQUEST: Pass tripType for Multiple Trip
      );
      
      if (result['success'] == true) {
        final invoiceAmount = result['invoice_amount'] as int? ?? 0;
        final tollCharges = result['toll_charges'] as int? ?? 0;
        
        // CRITICAL FIX: Log rate card result for every segment calculation
        print('[RFQ Create] Rate Card Result for Segment ($source → ${destination ?? 'N/A'}):');
        print('  Invoice Amount: ₹$invoiceAmount (${invoiceAmount == 0 ? 'BLANK/ZERO' : 'VALID'})');
        print('  Toll Charges: ₹$tollCharges (${tollCharges == 0 ? 'BLANK/ZERO' : 'VALID'})');
        print('  Weight: $weight kg');
        print('  Source: $source');
        print('  Destination: ${destination ?? 'N/A'}');
        print('  Trip Type: ${_selectedTripType == 'Multiple-Trip-Vendor' ? 'Multiple-Trip-Vendor (Drop rates)' : 'Other'}');
        
        return {
          'invoice_amount': invoiceAmount,
          'toll_charges': tollCharges,
        };
      } else {
        print('[RFQ Create] ⚠️ Rate calculation failed for segment: $source');
        print('  Error: ${result['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // CRITICAL FIX: Log error instead of silently handling
      print('[RFQ Create] ❌ Error calculating invoice for segment: $e');
    }
    
    // CRITICAL FIX: Default to 0 (not null) for numeric output
    return {'invoice_amount': 0, 'toll_charges': 0};
  }

  // Calculate invoice rate when source or weight changes
  // Part 1: For Round Trip, auto-populate invoice/toll when Starting Point, End Point, and Material Weight are entered
  // Rate Card Logic:
  // - If Starting Point is Factory and End Point is Vendor: Use Pick rates (source is Factory)
  // - If Starting Point is Vendor and End Point is Factory: Use Drop rates (source is Vendor)
  // CRITICAL FIX: Enhanced rate calculation with detailed logging
  Future<void> _calculateInvoiceRate() async {
    // For Round Trip: Require both source and destination to be selected
    if (_selectedTripType == 'Round-Trip-Vendor') {
      if (_selectedSource == null || _selectedSource!.isEmpty ||
          _selectedDestination == null || _selectedDestination!.isEmpty) {
        setState(() {
          _invoiceAmount = null;
          _tollCharges = null;
        });
        return;
      }
    } else {
      // For other trip types: Only require source
      if (_selectedSource == null || _selectedSource!.isEmpty) {
        setState(() {
          _invoiceAmount = null;
          _tollCharges = null;
        });
        return;
      }
    }
    
    final weight = int.tryParse(_materialWeightController.text);
    if (weight == null || weight < 0) {
      setState(() {
        _invoiceAmount = null;
        _tollCharges = null;
      });
      return;
    }
    
    setState(() {
      _isCalculatingInvoice = true;
    });
    
    try {
      // Part 1: For Round Trip, the API uses source location to determine Pick/Drop rates
      // - Factory source → Pick rates (pick_up_by_sol_*)
      // - Vendor source → Drop rates (dropped_by_vendor_*)
      // This is correct for Round Trip: Factory → Vendor uses Pick, Vendor → Factory uses Drop
      final result = await _apiService.calculateInvoiceRate(
        sourceLocation: _selectedSource!,
        materialWeight: weight,
      );
      
      if (result['success'] == true) {
        final calculatedInvoice = result['invoice_amount'] as int? ?? 0;
        final calculatedToll = result['toll_charges'] as int? ?? 0;
        
        // CRITICAL FIX: Log rate card result for every calculation
        print('[RFQ Create] Rate Card Result for ${_selectedSource}:');
        print('  Invoice Amount: ₹${calculatedInvoice} (${calculatedInvoice == 0 ? 'BLANK/ZERO' : 'VALID'})');
        print('  Toll Charges: ₹${calculatedToll} (${calculatedToll == 0 ? 'BLANK/ZERO' : 'VALID'})');
        print('  Weight: $weight kg');
        print('  Source: $_selectedSource');
        
        // CRITICAL FIX: Ensure numeric output - default to 0 if null
        setState(() {
          _autoCalculatedInvoice = calculatedInvoice;
          _autoCalculatedToll = calculatedToll;
          _invoiceAmount = calculatedInvoice;
          _tollCharges = calculatedToll;
          // Part 2: Update both controller and string state
          final invoiceString = calculatedInvoice?.toString() ?? '0';
          final tollString = calculatedToll?.toString() ?? '0';
          _invoiceAmountController.text = invoiceString;
          _tollChargesController.text = tollString;
          _manualInvoiceAmountString = invoiceString;
          _manualTollChargesString = tollString;
        });
      } else {
        setState(() {
          _invoiceAmount = null;
          _tollCharges = null;
          _autoCalculatedInvoice = null;
          _autoCalculatedToll = null;
          _invoiceAmountController.clear();
          _tollChargesController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _invoiceAmount = null;
        _tollCharges = null;
      });
    } finally {
      setState(() {
        _isCalculatingInvoice = false;
      });
    }
  }

  Future<void> _matchVehicles(int materialWeight) async {
    setState(() {
      _isMatchingVehicles = true;
      _showManualVehicleEntry = false;
    });

    try {
      final result = await _apiService.matchVehicles(materialWeight);
      if (result['success'] == true) {
        setState(() {
          _matchedVehicles = result['vehicles'] as List<VehicleModel>;
          _selectedVehicle = null;
          // Show manual entry option if no matches
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

  Future<void> _handleCreateRFQ() async {
    try {
      // Step 1: Validate form
      print('[RFQ Create] Step 1: Validating form...');
      if (!_formKey.currentState!.validate()) {
        print('[RFQ Create] Form validation failed');
        _showErrorModal('Form Validation Failed', 'Please fill in all required fields correctly.');
        return;
      }

      // Step 2: Validate source (skip for Multiple Trip - source is in segments)
      print('[RFQ Create] Step 2: Checking source selection...');
      if (_selectedTripType != 'Multiple-Trip-Vendor') {
        // For Single/Round/Internal trips, validate _selectedSource
        if (_selectedSource == null || _selectedSource!.isEmpty) {
          print('[RFQ Create] ERROR: Source not selected');
          _showErrorModal('Missing Information', 'Please select a starting point.');
          return;
        }

        // Step 3: Validate destination (skip for Multiple Trip - destination is in segments)
        print('[RFQ Create] Step 3: Checking destination...');
        if (_selectedDestination == null || _selectedDestination!.isEmpty) {
          print('[RFQ Create] ERROR: Destination not selected');
          _showErrorModal('Missing Information', 'Please select an end point.');
          return;
        }
      } else {
        // For Multiple Trip, validation is done in Step 7 (segment validation)
        print('[RFQ Create] Step 2-3: Skipping source/destination validation for Multiple Trip (validated in segments)');
      }

      // Step 3.5: Round Trip specific validation (frontend check to prevent unnecessary API calls)
      if (_selectedTripType == 'Round-Trip-Vendor') {
        print('[RFQ Create] Step 3.5: Validating Round Trip locations...');
        
        // Validation 1: Starting Point and End Point cannot be the same (MANDATORY)
        if (_selectedSource!.trim().toLowerCase() == _selectedDestination!.trim().toLowerCase()) {
          print('[RFQ Create] ERROR: Same location selected for Round Trip');
          _showErrorModal('Invalid Round Trip', 
              'Starting Point and End Point cannot be the same location for Round Trip.\n\n'
              'Please select different locations for the Starting Point and End Point.');
          return;
        }
        
        // Part 3: Multi-Trip Guardrail - Vendor → Vendor validation
        final isSourceFactory = _isFactoryLocation(_selectedSource);
        final isDestFactory = _isFactoryLocation(_selectedDestination);
        
        if (!isSourceFactory && !isDestFactory) {
          // Both are Vendors: Vendor → Vendor (NOT ALLOWED for Round Trip)
          print('[RFQ Create] ERROR: Vendor → Vendor route selected for Round Trip');
          _showErrorModal(
            'Invalid Round Trip Route',
            'Orders involving vendor-to-vendor movement must be created using the Multiple Trip order type.\n\n'
            'Please select two distinct locations that form a Factory ↔ Vendor route for a Round Trip.\n\n'
            'Selected:\n'
            '  Starting Point: $_selectedSource (Vendor)\n'
            '  End Point: $_selectedDestination (Vendor)'
          );
          return;
        }
        
        // Note: Backend will validate that A is Factory and B is Vendor
        // Frontend validation here prevents unnecessary API calls for same-location scenario
        print('[RFQ Create] ✓ Round Trip locations are different - backend will validate Factory/Vendor requirements');
      }

      // Step 4: Validate material weight (skip for Multiple Trip - weight is in segments)
      print('[RFQ Create] Step 4: Validating material weight...');
      if (_selectedTripType != 'Multiple-Trip-Vendor') {
        final materialWeight = int.tryParse(_materialWeightController.text.trim());
        if (materialWeight == null || materialWeight <= 0) {
          print('[RFQ Create] ERROR: Invalid material weight: ${_materialWeightController.text}');
          _showErrorModal('Invalid Input', 'Please enter a valid material weight (must be greater than 0).');
          return;
        }
      } else {
        // For Multiple Trip, weight validation is done in Step 7 (segment validation)
        print('[RFQ Create] Step 4: Skipping material weight validation for Multiple Trip (validated in segments)');
      }

      // Step 5: Validate vehicle selection or manual entry
      print('[RFQ Create] Step 5: Checking vehicle selection...');
      print('[RFQ Create]   - Selected Vehicle: ${_selectedVehicle?.vehicleId} / ${_selectedVehicle?.vehicleNumber}');
      print('[RFQ Create]   - Show Manual Entry: $_showManualVehicleEntry');
      
      bool hasVehicle = false;
      String? vehicleId;
      String? vehicleNumber;

      if (_selectedVehicle != null) {
        hasVehicle = true;
        vehicleId = _selectedVehicle!.vehicleId;
        vehicleNumber = _selectedVehicle!.vehicleNumber;
        print('[RFQ Create]   ✓ Vehicle selected: $vehicleNumber (ID: $vehicleId)');
      } else if (_showManualVehicleEntry) {
        print('[RFQ Create]   - Checking manual entry fields...');
        print('[RFQ Create]     - Manual Vehicle Number: ${_manualVehicleNumberController.text.trim()}');
        print('[RFQ Create]     - Manual Vehicle Type: $_manualVehicleType');
        print('[RFQ Create]     - Manual Capacity: ${_manualCapacityController.text.trim()}');
        
        if (_manualVehicleNumberController.text.trim().isEmpty ||
            _manualVehicleType == null ||
            _manualCapacityController.text.trim().isEmpty) {
          print('[RFQ Create]   ERROR: Manual entry incomplete');
          _showErrorModal('Incomplete Manual Entry', 
              'Please complete all manual vehicle entry fields:\n'
              '- Vehicle Number\n'
              '- Vehicle Type\n'
              '- Capacity (kg)');
          return;
        }
        hasVehicle = true;
        vehicleNumber = _manualVehicleNumberController.text.trim();
        print('[RFQ Create]   ✓ Manual vehicle entry complete: $vehicleNumber');
      }

      // Vehicle selection is now optional - order can be created without vehicle
      // Vehicle assignment will be required during Admin/Accounts approval
      if (!hasVehicle) {
        print('[RFQ Create]   INFO: No vehicle selected. Order will be created without vehicle assignment.');
        vehicleId = null;
        vehicleNumber = null;
      }

      // Step 6: Get user
      print('[RFQ Create] Step 6: Getting user information...');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        print('[RFQ Create] ERROR: User not found in auth provider');
        _showErrorModal('Authentication Error', 'User not found. Please login again.');
        return;
      }

      print('[RFQ Create]   ✓ User found: ${user.fullName} (ID: ${user.userId})');

      // Step 7: Prepare RFQ data based on trip type
      // CRITICAL FIX: Handle null destination for Multiple Trip
      final destination = _selectedTripType != 'Multiple-Trip-Vendor' 
          ? (_selectedDestination?.trim() ?? '')
          : null; // Multiple Trip doesn't use _selectedDestination
      final sourceValue = _selectedTripType != 'Multiple-Trip-Vendor'
          ? (_selectedSource?.trim() ?? '')
          : null; // Multiple Trip doesn't use _selectedSource
      
      // Debug logging to verify data binding
      print('[RFQ Create] Step 7.1: Verifying data binding...');
      if (_selectedTripType != 'Multiple-Trip-Vendor') {
        print('[RFQ Create]   - _selectedSource (raw): "${_selectedSource}"');
        print('[RFQ Create]   - _selectedDestination (raw): "${_selectedDestination}"');
        print('[RFQ Create]   - sourceValue (trimmed): "$sourceValue"');
        print('[RFQ Create]   - destination (trimmed): "$destination"');
      } else {
        print('[RFQ Create]   - Multiple Trip: Source/Destination from segments');
      }
      
      if (sourceValue != null && destination != null && sourceValue == destination) {
        print('[RFQ Create] ⚠️ WARNING: Source and Destination are identical!');
        if (_selectedTripType == 'Round-Trip-Vendor') {
          _showErrorModal('Invalid Selection', 
              'Starting Point and End Point cannot be the same location.\n\n'
              'Selected:\n'
              '  Starting Point: $sourceValue\n'
              '  End Point: $destination\n\n'
              'Please select different locations.');
          return;
        }
      }

      // Format material type as JSON array string
      // CRITICAL FIX: For Multiple Trip, consolidate material types from all segments
      String materialType = '';
      if (_selectedTripType != 'Multiple-Trip-Vendor') {
        if (_selectedMaterialTypes.isEmpty) {
          _showErrorModal('Missing Information', 'Please select at least one material type.');
          return;
        }
        List<String> materialTypeList = [];
        for (String type in _selectedMaterialTypes) {
          if (type == 'Other') {
            final otherName = _otherMaterialTypeController.text.trim();
            if (otherName.isNotEmpty) {
              materialTypeList.add('Other: $otherName');
            }
          } else {
            materialTypeList.add(type);
          }
        }
        // Convert to JSON array string
        materialType = jsonEncode(materialTypeList);
      }
      
      List<Map<String, dynamic>>? segments;
      String? source;
      String? finalDestination;
      
      if (_selectedTripType == 'Multiple-Trip-Vendor') {
        // Validate multiple segments
        if (_multipleSegments.isEmpty) {
          _showErrorModal('Missing Information', 'Please add at least one segment for Multiple Trip.');
          return;
        }
        
        // Validate all segments
        for (int i = 0; i < _multipleSegments.length; i++) {
          final seg = _multipleSegments[i];
          final selectedTypes = seg['selected_material_types'] as List<String>? ?? [];
          if (seg['source'] == null || seg['source'].toString().isEmpty ||
              seg['destination'] == null || seg['destination'].toString().isEmpty ||
              seg['material_weight'] == null || (seg['material_weight'] as int) <= 0 ||
              selectedTypes.isEmpty) {
            _showErrorModal('Incomplete Segment', 'Please complete all fields for Segment ${i + 1}.');
            return;
          }
          // Check if "Other" is selected but text is empty
          if (selectedTypes.contains('Other')) {
            final otherText = seg['other_material_text']?.toString() ?? '';
            if (otherText.trim().isEmpty) {
              _showErrorModal('Incomplete Segment', 'Please enter material name for "Other" in Segment ${i + 1}.');
              return;
            }
          }
          // Ensure material_type is set (JSON array)
          if (seg['material_type'] == null || seg['material_type'].toString().isEmpty) {
            // Format material type as JSON
            List<String> materialTypeList = [];
            for (String type in selectedTypes) {
              if (type == 'Other') {
                final otherName = seg['other_material_text']?.toString() ?? '';
                if (otherName.isNotEmpty) {
                  materialTypeList.add('Other: $otherName');
                }
              } else {
                materialTypeList.add(type);
              }
            }
            seg['material_type'] = jsonEncode(materialTypeList);
          }
        }
        
        segments = _multipleSegments;
        source = _multipleSegments[0]['source'].toString();
        finalDestination = _multipleSegments[_multipleSegments.length - 1]['destination'].toString();
        
        // CRITICAL FIX: For Multiple Trip, consolidate material types from all segments
        Set<String> allMaterialTypes = {};
        for (var segment in _multipleSegments) {
          try {
            final segMaterialType = segment['material_type']?.toString() ?? '';
            if (segMaterialType.isNotEmpty) {
              final parsed = jsonDecode(segMaterialType) as List<dynamic>;
              for (var type in parsed) {
                allMaterialTypes.add(type.toString());
              }
            }
          } catch (e) {
            // If parsing fails, skip this segment's material type
            print('[RFQ Create] Warning: Could not parse material_type for segment: $e');
          }
        }
        materialType = jsonEncode(allMaterialTypes.toList());
      } else {
        // Single-Trip-Vendor or Round-Trip-Vendor trip
        // CRITICAL FIX: Use trimmed sourceValue and destination, not raw _selectedSource/_selectedDestination
        source = sourceValue;
        // finalDestination is for display only (where trip ends)
        // For Round Trip, the trip ends back at source, but we still need to send the actual selected destination (B) to API
        finalDestination = _selectedTripType == 'Round-Trip-Vendor' ? sourceValue : destination;
      }

      print('[RFQ Create] Step 7.2: RFQ Data Prepared:');
      print('[RFQ Create]   - Trip Type: $_selectedTripType');
      print('[RFQ Create]   - User ID: ${user.userId}');
      print('[RFQ Create]   - Source (for API): $source');
      print('[RFQ Create]   - Destination (for API): ${_selectedTripType == 'Round-Trip-Vendor' ? destination : finalDestination}');
      print('[RFQ Create]   - Final Destination (display only): $finalDestination');
      
      // CRITICAL VALIDATION: Verify source and destination are different before API submission
      if (_selectedTripType == 'Round-Trip-Vendor' && source == destination) {
        print('[RFQ Create] ✗✗✗ CRITICAL ERROR: Source and Destination are identical after data preparation!');
        print('[RFQ Create]   - source: "$source"');
        print('[RFQ Create]   - destination: "$destination"');
        _showErrorModal('Data Binding Error', 
            'Starting Point and End Point are identical:\n\n'
            '  Both: $source\n\n'
            'This should not happen. Please select different locations.');
        return;
      }
      if (_selectedTripType != 'Multiple-Trip-Vendor') {
        final materialWeight = int.tryParse(_materialWeightController.text.trim());
        print('[RFQ Create]   - Material Weight: $materialWeight kg');
        print('[RFQ Create]   - Material Type: $materialType');
      }
      if (segments != null) {
        print('[RFQ Create]   - Segments Count: ${segments.length}');
      }
      print('[RFQ Create]   - Vehicle ID: ${vehicleId ?? 'N/A (Manual Entry)'}');
      print('[RFQ Create]   - Vehicle Number: $vehicleNumber');

      // Step 8: Create Order
      print('[RFQ Create] Step 8: Submitting Order to backend...');
      
      // CRITICAL FIX: For Round Trip, send actual selected destination (B), not finalDestination
      // finalDestination is only for display (shows trip ends at A)
      final apiDestination = _selectedTripType == 'Round-Trip-Vendor' 
          ? destination  // Send actual selected destination (B) for Round Trip
          : (_selectedTripType != 'Multiple-Trip-Vendor' ? finalDestination : null);
      
      // Final validation before API submission
      print('[RFQ Create] Step 8.1: Final payload verification...');
      print('[RFQ Create]   - API Source: ${_selectedTripType != 'Multiple-Trip-Vendor' ? source : 'N/A (Multiple Trip)'}');
      print('[RFQ Create]   - API Destination: $apiDestination');
      if (_selectedTripType == 'Round-Trip-Vendor') {
        print('[RFQ Create]   - Round Trip: Source (A) = "$source", Destination (B) = "$apiDestination"');
        if (source != null && apiDestination != null && source == apiDestination) {
          print('[RFQ Create] ✗✗✗ CRITICAL: Cannot submit - Source and Destination are identical!');
          _showErrorModal('Invalid Round Trip', 
              'Cannot create Round Trip with identical Starting Point and End Point.\n\n'
              'Selected: $source\n\n'
              'Please select different locations.');
          return;
        }
      }
      
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      // Extract materialWeight for non-Multiple Trip orders
      int? materialWeight;
      if (_selectedTripType != 'Multiple-Trip-Vendor') {
        materialWeight = int.tryParse(_materialWeightController.text.trim()) ?? 0;
      } else {
        // CRITICAL FIX: For Multiple Trip, calculate total weight from segments
        materialWeight = _calculateMultipleTripTotalWeight();
        if (materialWeight <= 0) {
          _showErrorModal('Invalid Weight', 'Total weight must be greater than 0 for Multiple Trip.');
          return;
        }
      }
      
      // CRITICAL FIX: For Multiple Trip, calculate totals from segments
      int? finalInvoiceAmount = _invoiceAmount;
      int? finalTollCharges = _tollCharges;
      if (_selectedTripType != 'Multiple-Trip-Vendor') {
        // Parse from string state if available
        if (_manualInvoiceAmountString.isNotEmpty) {
          finalInvoiceAmount = int.tryParse(_manualInvoiceAmountString) ?? 0;
        } else {
          finalInvoiceAmount = finalInvoiceAmount ?? 0;
        }
        if (_manualTollChargesString.isNotEmpty) {
          finalTollCharges = int.tryParse(_manualTollChargesString) ?? 0;
        } else {
          finalTollCharges = finalTollCharges ?? 0;
        }
      } else {
        // CRITICAL FIX: For Multiple Trip, calculate totals from segments
        // Parse string state from segments first
        if (segments != null) {
          for (var segment in segments) {
            if (segment['_invoice_string'] != null) {
              segment['invoice_amount'] = int.tryParse(segment['_invoice_string'].toString()) ?? (segment['invoice_amount'] ?? 0);
            }
            if (segment['_toll_string'] != null) {
              segment['toll_charges'] = int.tryParse(segment['_toll_string'].toString()) ?? (segment['toll_charges'] ?? 0);
            }
            // CRITICAL FIX: Ensure all segment fields have defaults
            segment['invoice_amount'] = segment['invoice_amount'] ?? 0;
            segment['toll_charges'] = segment['toll_charges'] ?? 0;
            segment['material_weight'] = segment['material_weight'] ?? 0;
          }
          
          // Calculate totals from segments
          int totalInvoice = 0;
          int totalToll = 0;
          for (var segment in segments) {
            totalInvoice += int.tryParse(segment['invoice_amount']?.toString() ?? '0') ?? 0;
            totalToll += int.tryParse(segment['toll_charges']?.toString() ?? '0') ?? 0;
          }
          finalInvoiceAmount = totalInvoice;
          finalTollCharges = totalToll;
          
          print('[RFQ Create] Step 8.2: Multiple Trip Totals Calculated:');
          print('[RFQ Create]   - Total Weight: $materialWeight kg');
          print('[RFQ Create]   - Total Invoice: ₹$finalInvoiceAmount');
          print('[RFQ Create]   - Total Toll: ₹$finalTollCharges');
          print('[RFQ Create]   - Material Type: $materialType');
        }
      }
      
      // CRITICAL FIX: Ensure materialType is not null/empty
      if (materialType.isEmpty) {
        print('[RFQ Create] ⚠️ WARNING: materialType is empty!');
        if (_selectedTripType == 'Multiple-Trip-Vendor') {
          // For Multiple Trip, materialType should be consolidated from segments
          materialType = jsonEncode([]); // Empty array as fallback
        } else {
          _showErrorModal('Missing Information', 'Material type is required.');
          return;
        }
      }
      
      // CRITICAL FIX: Log final payload before submission
      print('[RFQ Create] Step 8.3: Final Payload Summary:');
      print('[RFQ Create]   - Trip Type: $_selectedTripType');
      print('[RFQ Create]   - Source: ${_selectedTripType != 'Multiple-Trip-Vendor' ? source : 'N/A (from segments)'}');
      print('[RFQ Create]   - Destination: $apiDestination');
      print('[RFQ Create]   - Material Weight: $materialWeight kg');
      print('[RFQ Create]   - Material Type: $materialType');
      print('[RFQ Create]   - Invoice Amount: ₹${finalInvoiceAmount ?? 0}');
      print('[RFQ Create]   - Toll Charges: ₹${finalTollCharges ?? 0}');
      print('[RFQ Create]   - Vehicle ID: ${vehicleId ?? 'N/A (Manual Entry)'}');
      print('[RFQ Create]   - Vehicle Number: ${vehicleNumber ?? 'N/A (Manual Entry)'}');
      if (segments != null) {
        print('[RFQ Create]   - Segments Count: ${segments.length}');
      }
      
      final result = await orderProvider.createOrder(
        userId: user.userId,
        source: _selectedTripType != 'Multiple-Trip-Vendor' ? source : null,
        destination: apiDestination,
        materialWeight: materialWeight,
        materialType: materialType.isNotEmpty ? materialType : null, // CRITICAL FIX: Only send if not empty
        tripType: _selectedTripType,
        vehicleId: vehicleId,
        vehicleNumber: vehicleNumber,
        segments: segments,
        invoiceAmount: finalInvoiceAmount ?? 0, // CRITICAL FIX: Ensure not null
        tollCharges: finalTollCharges ?? 0, // CRITICAL FIX: Ensure not null
      );

      print('[RFQ Create] Step 9: Backend response received');
      print('[RFQ Create]   - Success: ${result['success']}');
      print('[RFQ Create]   - Message: ${result['message']}');

      if (!mounted) {
        print('[RFQ Create] WARNING: Widget unmounted, cannot show result');
        return;
      }

      if (result['success'] == true) {
        print('[RFQ Create] ✓ Order created successfully!');
        // Close modal and navigate to Orders Dashboard
        if (mounted) {
          // Step 1: Close the creation screen
          Navigator.of(context).pop();
          
          // Step 2: Wait for the navigation stack to unlock before redirecting
          // Use SchedulerBinding to ensure the pop completes before navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Navigate to Orders Dashboard after modal is fully closed
              Navigator.of(context).pushReplacementNamed('/orders');
            }
          });
        }
      } else {
        print('[RFQ Create] ✗ Order creation failed: ${result['message']}');
        _showErrorModal('Order Creation Failed', result['message'] ?? 'Failed to create order. Please try again.');
      }
    } catch (e, stackTrace) {
      print('[RFQ Create] ✗✗✗ EXCEPTION OCCURRED ✗✗✗');
      print('[RFQ Create] Error: $e');
      print('[RFQ Create] Stack Trace:');
      print(stackTrace.toString());
      
      if (mounted) {
        _showErrorModal(
          'Unexpected Error', 
          'An unexpected error occurred while creating the RFQ:\n\n$e\n\nPlease check the console for details.'
        );
      }
    }
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soliflex Packaging - Create Order'),
      ),
      body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trip Type Selection
                  _buildTripTypeSelector(),
                  const SizedBox(height: 24),
                  
                  // Conditional Form Fields based on Trip Type
                  if (_selectedTripType == 'Single-Trip-Vendor' || 
                      _selectedTripType == 'Round-Trip-Vendor')
                    _buildSingleRoundTripForm(),
                  if (_selectedTripType == 'Multiple-Trip-Vendor')
                    _buildMultipleTripForm(),
                
                const SizedBox(height: 32),
                
                // Vehicle Matching Section
                // CRITICAL FIX: Show for Single/Round Trip when weight is entered, OR for Multiple Trip when segments have weights
                if ((_selectedTripType != 'Multiple-Trip-Vendor' && _materialWeightController.text.isNotEmpty) ||
                    (_selectedTripType == 'Multiple-Trip-Vendor' && _calculateMultipleTripTotalWeight() > 0))
                  _buildVehicleMatchingSection(),
                
                // Manual Vehicle Entry Section
                if (_showManualVehicleEntry)
                  _buildManualVehicleEntry(),
                
                const SizedBox(height: 32),
                
                // Create Order Button
                Consumer<OrderProvider>(
                  builder: (context, orderProvider, child) {
                    return ElevatedButton(
                      onPressed: orderProvider.isLoading ? null : _handleCreateRFQ,
                      child: orderProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Create Order'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleMatchingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Matching',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (_isMatchingVehicles)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_matchedVehicles.isEmpty && 
                 ((_selectedTripType != 'Multiple-Trip-Vendor' && _materialWeightController.text.isNotEmpty) ||
                  (_selectedTripType == 'Multiple-Trip-Vendor' && _calculateMultipleTripTotalWeight() > 0)))
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
                    'Use the "Add Manual Truck Entry" button below to enter vehicle details manually.',
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
        
        // Always show "Add Manual Truck Entry" button
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (!_showManualVehicleEntry)
                  ElevatedButton.icon(
                    onPressed: () {
                      print('[RFQ Create] "Add Manual Truck Entry" button clicked');
                      setState(() {
                        _showManualVehicleEntry = true;
                        _selectedVehicle = null; // Clear selected vehicle when switching to manual
                      });
                      print('[RFQ Create]   ✓ Manual entry mode enabled');
                      print('[RFQ Create]   - _showManualVehicleEntry is now: $_showManualVehicleEntry');
                      print('[RFQ Create]   - _selectedVehicle cleared');
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Manual Truck Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6600),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Manual Entry Active',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          print('[RFQ Create] "Cancel Manual Entry" clicked');
                          setState(() {
                            _showManualVehicleEntry = false;
                            _manualVehicleNumberController.clear();
                            _manualVehicleType = null;
                            _manualCapacityController.clear();
                          });
                          print('[RFQ Create]   ✓ Manual entry cancelled');
                          print('[RFQ Create]   - _showManualVehicleEntry is now: $_showManualVehicleEntry');
                        },
                        child: const Text('Cancel Manual Entry'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    final utilization = vehicle.utilizationPercentage ?? 0;
    final isOptimal = vehicle.isOptimal ?? false;
    final isSelected = _selectedVehicle?.vehicleId == vehicle.vehicleId;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? const Color(0xFFFF6600) 
              : (isOptimal ? Colors.green : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          print('[RFQ Create] Vehicle selected:');
          print('[RFQ Create]   - Vehicle ID: ${vehicle.vehicleId}');
          print('[RFQ Create]   - Vehicle Number: ${vehicle.vehicleNumber}');
          print('[RFQ Create]   - Type: ${vehicle.type}');
          print('[RFQ Create]   - Capacity: ${vehicle.capacityKg} kg');
          print('[RFQ Create]   - Utilization: ${vehicle.utilizationPercentage?.toStringAsFixed(1)}%');
          
          setState(() {
            _selectedVehicle = vehicle;
            _showManualVehicleEntry = false;
            // Clear manual entry fields when selecting a vehicle
            _manualVehicleNumberController.clear();
            _manualVehicleType = null;
            _manualCapacityController.clear();
          });
          
          print('[RFQ Create]   ✓ Vehicle selection state updated');
          print('[RFQ Create]   - _selectedVehicle is now: ${_selectedVehicle?.vehicleId}');
          print('[RFQ Create]   - _showManualVehicleEntry is now: $_showManualVehicleEntry');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: const Color(0xFFFF6600),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              vehicle.vehicleNumber,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (isOptimal)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'OPTIMAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type: ${vehicle.type} | Capacity: ${vehicle.capacityKg} kg',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFFF6600),
                      size: 24,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Capacity Utilization Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${utilization.toStringAsFixed(1)}% Capacity Utilized',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isOptimal ? Colors.green : Colors.orange,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: utilization / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOptimal ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Trip Type Selector
  Widget _buildTripTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.route, color: Color(0xFFFF6600)),
                const SizedBox(width: 8),
                const Text(
                  'Trip Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTripTypeOption('Single-Trip-Vendor', Icons.arrow_forward, 'Single Trip Vendor'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTripTypeOption('Round-Trip-Vendor', Icons.swap_horiz, 'Round Trip Vendor'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTripTypeOption('Multiple-Trip-Vendor', Icons.route, 'Multiple Trip Vendor'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTripTypeOption(String type, IconData icon, String label) {
    final isSelected = _selectedTripType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTripType = type;
          // Reset multiple segments when switching trip types
          if (type != 'Multiple-Trip-Vendor') {
            _multipleSegments = [];
          }
          // Clear vehicle selection when switching
          _selectedVehicle = null;
          _matchedVehicles = [];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFFF6600).withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6600) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFF6600) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFFF6600) : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Single/Round Trip Form
  Widget _buildSingleRoundTripForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Source Dropdown
        Consumer<VendorProvider>(
          builder: (context, vendorProvider, child) {
            if (vendorProvider.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (vendorProvider.error != null) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Error: ${vendorProvider.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
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
                    const Text('No vendors found'),
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

            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Starting Point *',
                hintText: 'Select starting point',
                prefixIcon: Icon(Icons.location_on),
              ),
              value: _selectedSource,
              items: vendors.map((vendor) {
                return DropdownMenuItem<String>(
                  value: vendor.name,
                  child: Text(vendor.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSource = value;
                });
                _calculateInvoiceRate(); // Calculate invoice when source changes
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
        const SizedBox(height: 20),
        
        // Destination Selection (dropdown only, no custom option)
        Consumer<VendorProvider>(
          builder: (context, vendorProvider, child) {
            final vendors = vendorProvider.vendors;
            return DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: _selectedTripType == 'Round-Trip-Vendor' 
                    ? 'End Point *'
                    : 'End Point *',
                hintText: _selectedTripType == 'Round-Trip-Vendor'
                    ? 'End point'
                    : 'Select End point',
                prefixIcon: const Icon(Icons.location_on),
              ),
              value: _selectedDestination,
              items: vendors.map((vendor) {
                return DropdownMenuItem<String>(
                  value: vendor.name,
                  child: Text(vendor.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDestination = value;
                  // Part 1: For Round Trip, trigger invoice calculation when destination changes
                  if (_selectedTripType == 'Round-Trip-Vendor' && 
                      _selectedSource != null && 
                      _selectedSource!.isNotEmpty &&
                      _materialWeightController.text.isNotEmpty) {
                    _calculateInvoiceRate();
                  }
                });
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
        const SizedBox(height: 20),
        
        // Material Weight
        TextFormField(
          controller: _materialWeightController,
          decoration: const InputDecoration(
            labelText: 'Material Weight (kg) *',
            hintText: 'Enter weight in kilograms',
            prefixIcon: Icon(Icons.scale),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Material weight is required';
            }
            final weight = int.tryParse(value);
            if (weight == null || weight <= 0) {
              return 'Please enter a valid weight';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        
        // Material Type Multi-Select
        FormField<List<String>>(
          initialValue: _selectedMaterialTypes,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select at least one material type';
            }
            if (value.contains('Other') && _otherMaterialTypeController.text.trim().isEmpty) {
              return 'Please enter material name for "Other"';
            }
            return null;
          },
          builder: (field) {
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
                    final isSelected = _selectedMaterialTypes.contains(option);
                    return FilterChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_selectedMaterialTypes.contains(option)) {
                              _selectedMaterialTypes.add(option);
                            }
                          } else {
                            _selectedMaterialTypes.remove(option);
                            if (option == 'Other') {
                              _otherMaterialTypeController.clear();
                            }
                          }
                        });
                        field.didChange(_selectedMaterialTypes);
                      },
                      selectedColor: const Color(0xFFFF6600).withOpacity(0.3),
                      checkmarkColor: const Color(0xFFFF6600),
                      // CRITICAL FIX: Ensure text is always visible with proper contrast
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFFFF6600) : Colors.black87, // Changed from grey.shade700 to black87 for better visibility
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14, // Explicit font size
                      ),
                      backgroundColor: isSelected ? null : Colors.white, // Explicit white background when unselected
                    );
                  }).toList(),
                ),
                if (_selectedMaterialTypes.contains('Other')) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otherMaterialTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Other Material Name *',
                      hintText: 'Enter material name',
                      prefixIcon: Icon(Icons.edit),
                    ),
                    validator: (value) {
                      if (_selectedMaterialTypes.contains('Other') &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please enter material name';
                      }
                      return null;
                    },
                  ),
                ],
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      field.errorText ?? '',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        
        // Invoice Amount and Toll Charges (Editable, auto-calculated initially)
        if (_isCalculatingInvoice)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_invoiceAmount != null || _tollCharges != null) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _invoiceAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Amount *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // Part 2: Update string state first (allows multi-digit input)
                    setState(() {
                      _manualInvoiceAmountString = value;
                      // DO NOT parse to int here - only update string state
                    });
                  },
                  onEditingComplete: () {
                    // Part 2: Parse to int only when user finishes editing
                    setState(() {
                      _invoiceAmount = int.tryParse(_manualInvoiceAmountString);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _tollChargesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Toll Charges *',
                    prefixIcon: Icon(Icons.local_atm),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // Part 2: Update string state first (allows multi-digit input)
                    setState(() {
                      _manualTollChargesString = value;
                      // DO NOT parse to int here - only update string state
                    });
                  },
                  onEditingComplete: () {
                    // Part 2: Parse to int only when user finishes editing
                    setState(() {
                      _tollCharges = int.tryParse(_manualTollChargesString);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Multiple Trip Form
  Widget _buildMultipleTripForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_multipleSegments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Add segments to create a multiple trip order',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Each segment requires source, destination, weight, and material type.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        
        ..._multipleSegments.asMap().entries.map((entry) {
          final index = entry.key;
          final segment = entry.value;
          return _buildMultipleSegmentCard(index, segment);
        }).toList(),
        
        const SizedBox(height: 16),
        
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _multipleSegments.add({
                'source': '',
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
          label: const Text('Add Segment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleSegmentCard(int index, Map<String, dynamic> segment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Segment ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6600),
                  ),
                ),
                if (_multipleSegments.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _multipleSegments.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Source Dropdown
            Consumer<VendorProvider>(
              builder: (context, vendorProvider, child) {
                final vendors = vendorProvider.vendors;
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Starting Point *',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  value: segment['source']?.toString().isEmpty == false 
                      ? segment['source']?.toString()
                      : null,
                  items: vendors.map((vendor) {
                    return DropdownMenuItem<String>(
                      value: vendor.name,
                      child: Text(vendor.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      segment['source'] = value ?? '';
                      // CRITICAL FIX: Clear invoice/toll when source changes to force recalculation with new source
                      segment['invoice_amount'] = null;
                      segment['toll_charges'] = null;
                      segment['_last_calc_key'] = null; // Reset calculation key
                      // Part 1: Trigger invoice recalculation when source changes (for Multiple Trip)
                      // CRITICAL FIX: Use ONLY this segment's weight, not cumulative
                      final weight = int.tryParse(segment['material_weight']?.toString() ?? '0') ?? 0;
                      final destination = segment['destination']?.toString() ?? '';
                      if (value != null && value.isNotEmpty && destination.isNotEmpty && weight > 0) {
                        print('[Multiple Trip Segment ${index + 1}] Source changed to: $value, recalculating with weight: $weight kg (THIS SEGMENT ONLY)');
                        _calculateSegmentInvoice(value, weight, destination).then((result) {
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
                          }
                        });
                      }
                      
                      // CRITICAL FIX: Trigger vehicle matching for Multiple Trip when source changes (if weight is set)
                      if (weight > 0) {
                        _onMultipleTripWeightChanged();
                      }
                    });
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Destination Dropdown
            Consumer<VendorProvider>(
              builder: (context, vendorProvider, child) {
                final vendors = vendorProvider.vendors;
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'End Point *',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  value: segment['destination']?.toString().isEmpty == false 
                      ? segment['destination']?.toString()
                      : null,
                  items: vendors.map((vendor) {
                    return DropdownMenuItem<String>(
                      value: vendor.name,
                      child: Text(vendor.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      segment['destination'] = value ?? '';
                      // CRITICAL FIX: Clear invoice/toll when destination changes to force recalculation with new destination
                      segment['invoice_amount'] = null;
                      segment['toll_charges'] = null;
                      segment['_last_calc_key'] = null; // Reset calculation key
                      // Part 1: Trigger invoice recalculation when destination changes (for Multiple Trip)
                      // CRITICAL FIX: Use ONLY this segment's weight, not cumulative
                      final weight = int.tryParse(segment['material_weight']?.toString() ?? '0') ?? 0;
                      final source = segment['source']?.toString() ?? '';
                      if (value != null && value.isNotEmpty && source.isNotEmpty && weight > 0) {
                        print('[Multiple Trip Segment ${index + 1}] Destination changed to: $value, recalculating with weight: $weight kg (THIS SEGMENT ONLY)');
                        _calculateSegmentInvoice(source, weight, value).then((result) {
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
                          }
                        });
                      }
                      
                      // CRITICAL FIX: Trigger vehicle matching for Multiple Trip when destination changes (if weight is set)
                      if (weight > 0) {
                        _onMultipleTripWeightChanged();
                      }
                    });
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Material Weight
            TextFormField(
              initialValue: segment['material_weight']?.toString() ?? '0',
              decoration: const InputDecoration(
                labelText: 'Material Weight (kg) *',
                prefixIcon: Icon(Icons.scale),
              ),
              keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      // CRITICAL FIX: Store ONLY this segment's weight (not cumulative)
                      final newWeight = int.tryParse(value) ?? 0;
                      segment['material_weight'] = newWeight;
                      // CRITICAL FIX: Clear invoice/toll when weight changes to force recalculation with new weight
                      segment['invoice_amount'] = null;
                      segment['toll_charges'] = null;
                      segment['_last_calc_key'] = null; // Reset calculation key
                      // Part 1: Trigger invoice recalculation when weight changes (for Multiple Trip)
                      // CRITICAL FIX: Use ONLY this segment's weight, not cumulative
                      final source = segment['source']?.toString() ?? '';
                      final destination = segment['destination']?.toString() ?? '';
                      if (newWeight > 0 && source.isNotEmpty && destination.isNotEmpty) {
                        print('[Multiple Trip Segment ${index + 1}] Weight changed to: $newWeight kg (THIS SEGMENT ONLY, recalculating invoice)');
                        _calculateSegmentInvoice(source, newWeight, destination).then((result) {
                          if (mounted) {
                            setState(() {
                              // Part 2: Update both numeric and string state
                              final invoiceValue = result['invoice_amount'] ?? 0;
                              final tollValue = result['toll_charges'] ?? 0;
                              segment['invoice_amount'] = invoiceValue;
                              segment['toll_charges'] = tollValue;
                              segment['_invoice_string'] = invoiceValue.toString();
                              segment['_toll_string'] = tollValue.toString();
                              print('[Multiple Trip Segment ${index + 1}] Recalculated: Invoice: ₹$invoiceValue, Toll: ₹$tollValue');
                            });
                          }
                        });
                      }
                      
                      // CRITICAL FIX: Trigger vehicle matching for Multiple Trip when weight changes
                      _onMultipleTripWeightChanged();
                    });
                  },
            ),
            
            const SizedBox(height: 16),
            
            // Material Type Multi-Select for this segment
            FormField<List<String>>(
              initialValue: (segment['selected_material_types'] as List<String>?) ?? [],
              builder: (field) {
                List<String> selectedTypes = (segment['selected_material_types'] as List<String>?) ?? [];
                String otherText = (segment['other_material_text'] as String?) ?? '';
                
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
                          // CRITICAL FIX: Ensure text is always visible with proper contrast
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFFFF6600) : Colors.black87, // Changed from grey.shade700 to black87 for better visibility
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14, // Explicit font size
                          ),
                          backgroundColor: isSelected ? null : Colors.white, // Explicit white background when unselected
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
                          prefixIcon: Icon(Icons.edit),
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
                  ],
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Invoice Amount and Toll Charges for this segment
            // CRITICAL: Each segment calculates invoice independently based ONLY on its own weight
            // No accumulation or mixing of weights from other segments
            StatefulBuilder(
              builder: (context, setSegmentState) {
                final source = segment['source']?.toString() ?? '';
                final destination = segment['destination']?.toString() ?? '';
                // CRITICAL FIX: Use ONLY this segment's weight, not cumulative
                final weight = int.tryParse(segment['material_weight']?.toString() ?? '0') ?? 0;
                final invoiceAmount = segment['invoice_amount'] as int?;
                final tollCharges = segment['toll_charges'] as int?;
                
                // Part 1: Calculate invoice if source, destination, and weight are valid
                // For Multiple Trip, invoice calculation requires both source and destination for Pick/Drop logic
                // CRITICAL FIX: Each segment calculates independently - use ONLY this segment's weight
                if (source.isNotEmpty && destination.isNotEmpty && weight > 0 && (invoiceAmount == null || tollCharges == null)) {
                  // CRITICAL FIX: Ensure we use ONLY this segment's weight, not cumulative
                  final segmentWeight = int.tryParse(segment['material_weight']?.toString() ?? '0') ?? 0;
                  
                  // Use a unique key to prevent multiple simultaneous calculations for the same segment
                  final segmentKey = '${source}_${destination}_$segmentWeight';
                  
                  // Only calculate if we haven't already calculated for this exact combination
                  if (segment['_last_calc_key'] != segmentKey) {
                    segment['_last_calc_key'] = segmentKey;
                    
                    print('[Multiple Trip Segment ${index + 1}] Calculating invoice independently:');
                    print('  Source: $source');
                    print('  Destination: $destination');
                    print('  Weight: $segmentWeight kg (THIS SEGMENT ONLY, not cumulative)');
                    
                    _calculateSegmentInvoice(source, segmentWeight, destination).then((result) {
                      if (mounted) {
                        setState(() {
                          // Part 2: Update both numeric and string state
                          final invoiceValue = result['invoice_amount'] ?? 0;
                          final tollValue = result['toll_charges'] ?? 0;
                          segment['invoice_amount'] = invoiceValue;
                          segment['toll_charges'] = tollValue;
                          segment['_invoice_string'] = invoiceValue.toString();
                          segment['_toll_string'] = tollValue.toString();
                          print('[Multiple Trip Segment ${index + 1}] Calculated: Invoice: ₹$invoiceValue, Toll: ₹$tollValue');
                        });
                      }
                    });
                  }
                }
                
                if (invoiceAmount != null || tollCharges != null) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('invoice_${index}_${invoiceAmount}'), // Unique key to prevent state mixing
                          controller: TextEditingController(
                            text: (segment['_invoice_string'] as String?) ?? (invoiceAmount ?? 0).toString(),
                          )..selection = TextSelection.fromPosition(
                            TextPosition(offset: (segment['_invoice_string'] as String?)?.length ?? (invoiceAmount ?? 0).toString().length),
                          ),
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr, // CRITICAL FIX: Force left-to-right text direction
                          decoration: const InputDecoration(
                            labelText: 'Invoice Amount',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            // CRITICAL FIX: Use localized state update (minimize rebuild scope)
                            // Update string state first (allows multi-digit input)
                            setSegmentState(() {
                              segment['_invoice_string'] = value;
                              // DO NOT parse to int here - only update string state
                            });
                          },
                          onEditingComplete: () {
                            // Part 2: Parse to int only when user finishes editing
                            setSegmentState(() {
                              final stringValue = segment['_invoice_string'] as String? ?? '';
                              segment['invoice_amount'] = int.tryParse(stringValue) ?? 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('toll_${index}_${tollCharges}'), // Unique key to prevent state mixing
                          controller: TextEditingController(
                            text: (segment['_toll_string'] as String?) ?? (tollCharges ?? 0).toString(),
                          )..selection = TextSelection.fromPosition(
                            TextPosition(offset: (segment['_toll_string'] as String?)?.length ?? (tollCharges ?? 0).toString().length),
                          ),
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr, // CRITICAL FIX: Force left-to-right text direction
                          decoration: const InputDecoration(
                            labelText: 'Toll Charges',
                            prefixIcon: Icon(Icons.local_atm),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            // CRITICAL FIX: Use localized state update (minimize rebuild scope)
                            // Update string state first (allows multi-digit input)
                            setSegmentState(() {
                              segment['_toll_string'] = value;
                              // DO NOT parse to int here - only update string state
                            });
                          },
                          onEditingComplete: () {
                            // Part 2: Parse to int only when user finishes editing
                            setSegmentState(() {
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
          ],
        ),
      ),
    );
  }

  Widget _buildManualVehicleEntry() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Manual Truck Entry',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900, // Dark blue for better contrast on light blue background
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _manualVehicleNumberController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number *',
                hintText: 'Enter vehicle number',
                prefixIcon: Icon(Icons.numbers),
              ),
              onChanged: (value) {
                print('[RFQ Create] Manual vehicle number changed: $value');
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vehicle number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Vehicle Type *',
                prefixIcon: Icon(Icons.local_shipping),
              ),
              value: _manualVehicleType,
              items: const [
                DropdownMenuItem(value: 'Open', child: Text('Open')),
                DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                DropdownMenuItem(value: 'Container', child: Text('Container')),
              ],
              onChanged: (value) {
                print('[RFQ Create] Manual vehicle type changed: $value');
                setState(() {
                  _manualVehicleType = value;
                });
                print('[RFQ Create]   ✓ Manual vehicle type set to: $_manualVehicleType');
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select vehicle type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _manualCapacityController,
              decoration: const InputDecoration(
                labelText: 'Capacity (kg) *',
                hintText: 'Enter capacity in kg',
                prefixIcon: Icon(Icons.scale),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                print('[RFQ Create] Manual vehicle capacity changed: $value');
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Capacity is required';
                }
                final capacity = int.tryParse(value);
                if (capacity == null || capacity <= 0) {
                  return 'Please enter a valid capacity';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

