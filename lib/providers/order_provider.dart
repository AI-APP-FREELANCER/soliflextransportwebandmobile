import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all orders
  Future<void> loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getOrders();
      if (result['success'] == true) {
        _orders = result['orders'] as List<OrderModel>;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load orders';
      }
    } catch (e) {
      _error = 'Error loading orders: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user's orders
  Future<void> loadUserOrders(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getUserOrders(userId);
      if (result['success'] == true) {
        _orders = result['orders'] as List<OrderModel>;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load orders';
      }
    } catch (e) {
      _error = 'Error loading orders: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create order
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.createOrder(
        userId: userId,
        source: source,
        destination: destination,
        materialWeight: materialWeight,
        materialType: materialType,
        tripType: tripType,
        vehicleId: vehicleId,
        vehicleNumber: vehicleNumber,
        segments: segments,
        invoiceAmount: invoiceAmount,
        tollCharges: tollCharges,
      );

      if (result['success'] == true) {
        // Reload orders after creating
        await loadOrders();
        return {
          'success': true,
          'message': result['message'] ?? 'Order created successfully',
          'order': result['order'],
        };
      } else {
        _error = result['message'] ?? 'Failed to create order';
        return {
          'success': false,
          'message': _error ?? 'Failed to create order',
        };
      }
    } catch (e) {
      _error = 'Error creating order: ${e.toString()}';
      return {
        'success': false,
        'message': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Amend order by adding new segments
  Future<Map<String, dynamic>> amendOrder({
    required String orderId,
    required List<Map<String, dynamic>> newSegments,
    required String userId, // Add userId for audit trail
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.amendOrder(
        orderId: orderId,
        newSegments: newSegments,
        userId: userId, // Pass userId for audit trail
      );

      if (result['success'] == true) {
        // Reload orders after amending
        await loadOrders();
        return {
          'success': true,
          'message': result['message'] ?? 'Order amended successfully',
          'order': result['order'],
        };
      } else {
        _error = result['message'] ?? 'Failed to amend order';
        return {
          'success': false,
          'message': _error ?? 'Failed to amend order',
        };
      }
    } catch (e) {
      _error = 'Error amending order: ${e.toString()}';
      return {
        'success': false,
        'message': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update order status
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? userId, // Optional userId for audit tracking
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.updateOrderStatus(
        orderId: orderId,
        newStatus: newStatus,
        userId: userId,
      );

      if (result['success'] == true) {
        // Reload orders after updating
        await loadOrders();
        return {
          'success': true,
          'message': result['message'] ?? 'Order status updated successfully',
          'order': result['order'],
        };
      } else {
        _error = result['message'] ?? 'Failed to update order status';
        return {
          'success': false,
          'message': _error ?? 'Failed to update order status',
        };
      }
    } catch (e) {
      _error = 'Error updating order status: ${e.toString()}';
      return {
        'success': false,
        'message': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

