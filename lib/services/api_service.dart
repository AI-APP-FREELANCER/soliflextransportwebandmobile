import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../models/vendor_model.dart';
import '../models/vehicle_model.dart';
import '../models/rfq_model.dart';
import '../models/order_model.dart';
import '../models/notification_model.dart';

// Conditional import for web
import 'dart:html' as html if (dart.library.html) 'dart:html';

class ApiService {
  // Dynamically determine base URL based on platform
  // For web: Use current hostname and protocol (works for both localhost, VM IP, and subdomain)
  // For mobile: Use localhost or configured IP
  static String get baseUrl {
    if (kIsWeb) {
      // For web, use the current hostname, protocol, and port
      final hostname = html.window.location.hostname ?? 'localhost';
      final protocol = html.window.location.protocol; // Gets 'http:' or 'https:'
      final baseProtocol = protocol == 'https:' ? 'https' : 'http';
      
      // If using subdomain (e.g., transport.soliflexpackaging.com), use /api path
      // If using IP or localhost, use :3000 port
      final ipRegex = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
      final isIpAddress = ipRegex.hasMatch(hostname);

      if (!isIpAddress && hostname.contains('.') && !hostname.startsWith('localhost') && !hostname.startsWith('127.0.0.1') && !hostname.startsWith('192.168.')) {
        // Subdomain or domain - use /api path (Nginx will proxy to backend)
        return '$baseProtocol://$hostname/api';
      } else {
        // IP address or localhost - use :3000 port directly
        return '$baseProtocol://$hostname:3000/api';
      }
    } else {
      // For mobile/emulator, use localhost or configured IP
      // - Android Emulator: http://10.0.2.2:3000/api
      // - iOS Simulator: http://localhost:3000/api
      // - Physical Device: Use your computer's IP address, e.g., http://192.168.1.100:3000/api
      return 'http://localhost:3000/api';
    }
  }

  // Register a new user
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String password,
    required String department,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'password': password,
          'department': department,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'user': data['user'] != null ? UserModel.fromJson(data['user'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'user': null,
      };
    }
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String fullName,
    required String password,
    required String department,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'password': password,
          'department': department,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'user': data['user'] != null ? UserModel.fromJson(data['user'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'user': null,
      };
    }
  }

  // Get all departments
  Future<Map<String, dynamic>> getDepartments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/departments'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'departments': data['departments'] != null
            ? (data['departments'] as List<dynamic>)
                .map((d) => d.toString())
                .toList()
            : <String>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'departments': <String>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get user by ID
  Future<Map<String, dynamic>> getUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'user': data['user'] != null ? UserModel.fromJson(data['user'] as Map<String, dynamic>) : null,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'user': null,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get all vendors
  Future<Map<String, dynamic>> getVendors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vendors'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'vendors': <VendorModel>[],
          'message': 'Failed to load vendors: ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (data['success'] == true && data['vendors'] != null) {
        try {
          final vendorsList = (data['vendors'] as List<dynamic>)
              .map((v) {
                try {
                  return VendorModel.fromJson(v as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing vendor: $v, Error: $e');
                  return null;
                }
              })
              .whereType<VendorModel>()
              .toList();
          
          return {
            'success': true,
            'vendors': vendorsList,
            'message': data['message'] ?? '',
          };
        } catch (e) {
          return {
            'success': false,
            'vendors': <VendorModel>[],
            'message': 'Error parsing vendors: ${e.toString()}',
          };
        }
      }
      
      return {
        'success': data['success'] ?? false,
        'vendors': <VendorModel>[],
        'message': data['message'] ?? 'No vendors returned',
      };
    } catch (e) {
      return {
        'success': false,
        'vendors': <VendorModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get all vehicles
  Future<Map<String, dynamic>> getVehicles({bool? isBusy}) async {
    try {
      String url = '$baseUrl/vehicles';
      if (isBusy != null) {
        url += '?isBusy=${isBusy.toString()}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'vehicles': data['vehicles'] != null
            ? (data['vehicles'] as List<dynamic>)
                .map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
                .toList()
            : <VehicleModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'vehicles': <VehicleModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Match vehicles for material weight
  Future<Map<String, dynamic>> matchVehicles(int materialWeight) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rfq/match-vehicles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'materialWeight': materialWeight,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'vehicles': data['vehicles'] != null
            ? (data['vehicles'] as List<dynamic>)
                .map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
                .toList()
            : <VehicleModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'vehicles': <VehicleModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Create RFQ
  Future<Map<String, dynamic>> createRFQ({
    required String userId,
    required String source,
    required String destination,
    required int materialWeight,
    required String materialType,
    String? vehicleId,
    String? vehicleNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rfq/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'source': source,
          'destination': destination,
          'materialWeight': materialWeight,
          'materialType': materialType,
          if (vehicleId != null) 'vehicleId': vehicleId,
          if (vehicleNumber != null) 'vehicle_number': vehicleNumber,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'rfq': data['rfq'] != null ? RFQModel.fromJson(data['rfq'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'rfq': null,
      };
    }
  }

  // Get user's RFQs
  Future<Map<String, dynamic>> getUserRFQs(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rfq/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'rfqs': data['rfqs'] != null
            ? (data['rfqs'] as List<dynamic>)
                .map((r) => RFQModel.fromJson(r as Map<String, dynamic>))
                .toList()
            : <RFQModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'rfqs': <RFQModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get pending RFQs
  Future<Map<String, dynamic>> getPendingRFQs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rfq/pending'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'rfqs': data['rfqs'] != null
            ? (data['rfqs'] as List<dynamic>)
                .map((r) => RFQModel.fromJson(r as Map<String, dynamic>))
                .toList()
            : <RFQModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'rfqs': <RFQModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Approve RFQ
  Future<Map<String, dynamic>> approveRFQ(String rfqId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rfq/$rfqId/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'rfq': data['rfq'] != null ? RFQModel.fromJson(data['rfq'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'rfq': null,
      };
    }
  }

  // Reject RFQ
  Future<Map<String, dynamic>> rejectRFQ(String rfqId, String userId, String rejectionReason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rfq/$rfqId/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'rejectionReason': rejectionReason,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'rfq': data['rfq'] != null ? RFQModel.fromJson(data['rfq'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'rfq': null,
      };
    }
  }

  // Start trip
  Future<Map<String, dynamic>> startTrip(String rfqId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rfq/$rfqId/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'rfq': data['rfq'] != null ? RFQModel.fromJson(data['rfq'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'rfq': null,
      };
    }
  }

  // Complete trip
  Future<Map<String, dynamic>> completeTrip(String rfqId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rfq/$rfqId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'rfq': data['rfq'] != null ? RFQModel.fromJson(data['rfq'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'rfq': null,
      };
    }
  }

  // Create Order
  Future<Map<String, dynamic>> createOrder({
    required String userId,
    String? source,
    String? destination,
    int? materialWeight,
    String? materialType,
    String tripType = 'Single-Trip-Vendor',
    String? vehicleId,
    String? vehicleNumber,
    List<Map<String, dynamic>>? segments, // For Multiple trip type
    int? invoiceAmount,
    int? tollCharges,
  }) async {
    try {
      final body = <String, dynamic>{
        'userId': userId,
        'tripType': tripType,
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
      };
      
      // For Single-Trip-Vendor, Round-Trip-Vendor, and Internal-Transfer trips, include source, destination, materialWeight, materialType
      if (tripType == 'Single-Trip-Vendor' || 
          tripType == 'Round-Trip-Vendor' ||
          tripType == 'Internal-Transfer') {
        if (source != null) body['source'] = source;
        if (destination != null) body['destination'] = destination;
        if (materialWeight != null) body['materialWeight'] = materialWeight;
        if (materialType != null) body['materialType'] = materialType;
        if (invoiceAmount != null) body['invoiceAmount'] = invoiceAmount;
        if (tollCharges != null) body['tollCharges'] = tollCharges;
      }
      
      // For Multiple-Trip-Vendor trip type, include segments array
      if (tripType == 'Multiple-Trip-Vendor' && segments != null && segments.isNotEmpty) {
        body['segments'] = segments;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Failed to create order: ${response.statusCode}',
          'order': null,
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'order': data['order'] != null
            ? OrderModel.fromJson(data['order'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'order': null,
      };
    }
  }

  // Amend order by adding new segments
  Future<Map<String, dynamic>> amendOrder({
    required String orderId,
    required List<Map<String, dynamic>> newSegments,
    required String userId, // Add userId for audit trail
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/amend-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'newSegments': newSegments,
          'userId': userId, // Include userId for audit trail
        }),
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Failed to amend order: ${response.statusCode}',
          'order': null,
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'order': data['order'] != null ? OrderModel.fromJson(data['order'] as Map<String, dynamic>) : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'order': null,
      };
    }
  }

  // Calculate invoice rate based on source location and material weight
  // USER REQUEST: For Multiple Trip, ALWAYS use Drop rates (dropped_by_vendor_*) for all segments
  Future<Map<String, dynamic>> calculateInvoiceRate({
    required String sourceLocation,
    required int materialWeight,
    String? destinationLocation, // Optional destination for segment calculation
    String? tripType, // USER REQUEST: Pass tripType to force Drop rates for Multiple Trip
  }) async {
    try {
      final body = {
        'source_location': sourceLocation,
        'material_weight': materialWeight,
      };
      
      // Include destination if provided (for segment calculation)
      if (destinationLocation != null && destinationLocation.isNotEmpty) {
        body['destination_location'] = destinationLocation;
      }
      
      // USER REQUEST: Include tripType if provided (for Multiple Trip to force Drop rates)
      if (tripType != null && tripType.isNotEmpty) {
        body['trip_type'] = tripType;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/calculate-invoice-rate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to calculate invoice rate',
          'invoice_amount': 0,
          'toll_charges': 0,
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'invoice_amount': data['invoice_amount'] ?? 0,
        'toll_charges': data['toll_charges'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'invoice_amount': 0,
        'toll_charges': 0,
      };
    }
  }

  // Assign Vehicle to Order
  Future<Map<String, dynamic>> assignVehicleToOrder({
    required String orderId,
    String? vehicleId,
    required String vehicleNumber,
    String? vehicleType,
    int? capacityKg,
    String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/assign-vehicle-to-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          if (vehicleId != null) 'vehicleId': vehicleId,
          'vehicleNumber': vehicleNumber,
          if (vehicleType != null) 'vehicleType': vehicleType,
          if (capacityKg != null) 'capacityKg': capacityKg,
          if (userId != null) 'userId': userId,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to assign vehicle: ${response.statusCode}',
          'order': null,
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'order': data['order'] != null
            ? OrderModel.fromJson(data['order'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'order': null,
      };
    }
  }

  // Update Order Status
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? userId, // Optional userId for audit tracking
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update-order-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'newStatus': newStatus,
          if (userId != null) 'userId': userId,
        }),
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Failed to update order status: ${response.statusCode}',
          'order': null,
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'order': data['order'] != null
            ? OrderModel.fromJson(data['order'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'order': null,
      };
    }
  }

  // Get all orders
  Future<Map<String, dynamic>> getOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'orders': <OrderModel>[],
          'message': 'Failed to load orders: ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (data['success'] == true && data['orders'] != null) {
        try {
          final ordersList = (data['orders'] as List<dynamic>)
              .map((o) {
                try {
                  return OrderModel.fromJson(o as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing order: $o, Error: $e');
                  return null;
                }
              })
              .whereType<OrderModel>()
              .toList();
          
          return {
            'success': true,
            'orders': ordersList,
            'message': data['message'] ?? '',
          };
        } catch (e) {
          return {
            'success': false,
            'orders': <OrderModel>[],
            'message': 'Error parsing orders: ${e.toString()}',
          };
        }
      }
      
      return {
        'success': data['success'] ?? false,
        'orders': <OrderModel>[],
        'message': data['message'] ?? 'No orders returned',
      };
    } catch (e) {
      return {
        'success': false,
        'orders': <OrderModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get user orders
  Future<Map<String, dynamic>> getUserOrders(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        return {
          'success': false,
          'orders': <OrderModel>[],
          'message': 'Failed to load user orders: ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (data['success'] == true && data['orders'] != null) {
        try {
          final ordersList = (data['orders'] as List<dynamic>)
              .map((o) {
                try {
                  return OrderModel.fromJson(o as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing order: $o, Error: $e');
                  return null;
                }
              })
              .whereType<OrderModel>()
              .toList();
          
          return {
            'success': true,
            'orders': ordersList,
            'message': data['message'] ?? '',
          };
        } catch (e) {
          return {
            'success': false,
            'orders': <OrderModel>[],
            'message': 'Error parsing orders: ${e.toString()}',
          };
        }
      }
      
      return {
        'success': data['success'] ?? false,
        'orders': <OrderModel>[],
        'message': data['message'] ?? 'No orders returned',
      };
    } catch (e) {
      return {
        'success': false,
        'orders': <OrderModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get order by ID
  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 404) {
        return {
          'success': false,
          'order': null,
          'message': 'Order not found',
        };
      }

      if (response.statusCode != 200) {
        return {
          'success': false,
          'order': null,
          'message': 'Failed to load order: ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      return {
        'success': data['success'] ?? false,
        'order': data['order'] != null
            ? OrderModel.fromJson(data['order'] as Map<String, dynamic>)
            : null,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'order': null,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Initialize workflow for an order
  Future<Map<String, dynamic>> initializeWorkflow(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/initialize-workflow'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': orderId}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'order': data['order'] != null
            ? OrderModel.fromJson(data['order'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'order': null,
      };
    }
  }

  // Perform workflow action (approve/reject/revoke/cancel)
  Future<Map<String, dynamic>> performWorkflowAction({
    required String orderId,
    required int segmentId,
    required String stage,
    required String action,
    required String userId,
    String? comments,
    String? location,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/workflow-action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'segmentId': segmentId,
          'stage': stage,
          'action': action,
          'userId': userId,
          'comments': comments,
          if (location != null) 'location': location,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'order': data['order'] != null
            ? OrderModel.fromJson(data['order'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'order': null,
      };
    }
  }

  // ============================================
  // ADMIN CRUD OPERATIONS - USERS
  // ============================================

  // GET /api/admin/users
  Future<Map<String, dynamic>> getAdminUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'users': data['users'] != null
            ? (data['users'] as List<dynamic>)
                .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
                .toList()
            : <UserModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'users': <UserModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // POST /api/admin/users
  Future<Map<String, dynamic>> createAdminUser({
    required String fullName,
    required String password,
    required String department,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'password': password,
          'department': department,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'user': data['user'] != null
            ? UserModel.fromJson(data['user'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'user': null,
      };
    }
  }

  // PUT /api/admin/users/:userId
  Future<Map<String, dynamic>> updateAdminUser({
    required String userId,
    String? fullName,
    String? password,
    String? department,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (fullName != null) 'fullName': fullName,
          if (password != null) 'password': password,
          if (department != null) 'department': department,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'user': data['user'] != null
            ? UserModel.fromJson(data['user'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'user': null,
      };
    }
  }

  // DELETE /api/admin/users/:userId
  Future<Map<String, dynamic>> deleteAdminUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // ============================================
  // ADMIN CRUD OPERATIONS - VENDORS
  // ============================================

  // GET /api/admin/vendors
  Future<Map<String, dynamic>> getAdminVendors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/vendors'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'vendors': data['vendors'] != null
            ? (data['vendors'] as List<dynamic>)
                .map((v) => VendorModel.fromJson(v as Map<String, dynamic>))
                .toList()
            : <VendorModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'vendors': <VendorModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // POST /api/admin/vendors
  Future<Map<String, dynamic>> createAdminVendor(Map<String, dynamic> vendorData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/vendors'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(vendorData),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'vendor': data['vendor'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'vendor': null,
      };
    }
  }

  // PUT /api/admin/vendors/:vendorName
  Future<Map<String, dynamic>> updateAdminVendor({
    required String vendorName,
    required Map<String, dynamic> vendorData,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/vendors/${Uri.encodeComponent(vendorName)}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(vendorData),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'vendor': data['vendor'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'vendor': null,
      };
    }
  }

  // DELETE /api/admin/vendors/:vendorName
  Future<Map<String, dynamic>> deleteAdminVendor(String vendorName) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/vendors/${Uri.encodeComponent(vendorName)}'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // ============================================
  // ADMIN CRUD OPERATIONS - VEHICLES
  // ============================================

  // GET /api/admin/vehicles
  Future<Map<String, dynamic>> getAdminVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/vehicles'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'vehicles': data['vehicles'] != null
            ? (data['vehicles'] as List<dynamic>)
                .map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
                .toList()
            : <VehicleModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'vehicles': <VehicleModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // POST /api/admin/vehicles
  Future<Map<String, dynamic>> createAdminVehicle(Map<String, dynamic> vehicleData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/vehicles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(vehicleData),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'vehicle': data['vehicle'] != null
            ? VehicleModel.fromJson(data['vehicle'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'vehicle': null,
      };
    }
  }

  // PUT /api/admin/vehicles/:vehicleId
  Future<Map<String, dynamic>> updateAdminVehicle({
    required String vehicleId,
    required Map<String, dynamic> vehicleData,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/vehicles/$vehicleId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(vehicleData),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'vehicle': data['vehicle'] != null
            ? VehicleModel.fromJson(data['vehicle'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'vehicle': null,
      };
    }
  }

  // DELETE /api/admin/vehicles/:vehicleId
  Future<Map<String, dynamic>> deleteAdminVehicle(String vehicleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/vehicles/$vehicleId'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // ============================================
  // NOTIFICATION OPERATIONS
  // ============================================

  // GET /api/notifications/department/:department
  Future<Map<String, dynamic>> getNotificationsByDepartment(String department) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/department/${Uri.encodeComponent(department)}'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'notifications': data['notifications'] != null
            ? (data['notifications'] as List<dynamic>)
                .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
                .toList()
            : <NotificationModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'notifications': <NotificationModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // GET /api/notifications/user/:userId
  Future<Map<String, dynamic>> getNotificationsForUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'notifications': data['notifications'] != null
            ? (data['notifications'] as List<dynamic>)
                .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
                .toList()
            : <NotificationModel>[],
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'notifications': <NotificationModel>[],
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // POST /api/notifications/:notificationId/read
  Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? '',
        'notification': data['notification'] != null
            ? NotificationModel.fromJson(data['notification'] as Map<String, dynamic>)
            : null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'notification': null,
      };
    }
  }

  // GET /api/notifications/unread-count/:department
  Future<Map<String, dynamic>> getUnreadNotificationCount(String department) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count/${Uri.encodeComponent(department)}'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'count': data['count'] ?? 0,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'count': 0,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
