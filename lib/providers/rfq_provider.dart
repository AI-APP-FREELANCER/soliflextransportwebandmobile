import 'package:flutter/foundation.dart';
import '../models/rfq_model.dart';
import '../services/api_service.dart';

class RFQProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<RFQModel> _rfqs = [];
  List<RFQModel> _pendingRFQs = [];
  bool _isLoading = false;
  String? _error;

  List<RFQModel> get rfqs => _rfqs;
  List<RFQModel> get pendingRFQs => _pendingRFQs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load user's RFQs
  Future<void> loadUserRFQs(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getUserRFQs(userId);
      if (result['success'] == true) {
        _rfqs = result['rfqs'] as List<RFQModel>;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load RFQs';
      }
    } catch (e) {
      _error = 'Error loading RFQs: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load pending RFQs (for approval manager)
  Future<void> loadPendingRFQs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getPendingRFQs();
      if (result['success'] == true) {
        _pendingRFQs = result['rfqs'] as List<RFQModel>;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load pending RFQs';
      }
    } catch (e) {
      _error = 'Error loading pending RFQs: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.createRFQ(
        userId: userId,
        source: source,
        destination: destination,
        materialWeight: materialWeight,
        materialType: materialType,
        vehicleId: vehicleId,
        vehicleNumber: vehicleNumber,
      );

      if (result['success'] == true) {
        // Reload user's RFQs
        await loadUserRFQs(userId);
        return {
          'success': true,
          'message': result['message'] ?? 'RFQ created successfully',
          'rfq': result['rfq'],
        };
      } else {
        _error = result['message'] ?? 'Failed to create RFQ';
        return {
          'success': false,
          'message': _error ?? 'Failed to create RFQ',
        };
      }
    } catch (e) {
      _error = 'Error creating RFQ: ${e.toString()}';
      return {
        'success': false,
        'message': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Approve RFQ
  Future<bool> approveRFQ(String rfqId, String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.approveRFQ(rfqId, userId);
      if (result['success'] == true) {
        // Reload pending RFQs
        await loadPendingRFQs();
        return true;
      } else {
        _error = result['message'] ?? 'Failed to approve RFQ';
        return false;
      }
    } catch (e) {
      _error = 'Error approving RFQ: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reject RFQ
  Future<bool> rejectRFQ(String rfqId, String userId, String rejectionReason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.rejectRFQ(rfqId, userId, rejectionReason);
      if (result['success'] == true) {
        // Reload pending RFQs
        await loadPendingRFQs();
        return true;
      } else {
        _error = result['message'] ?? 'Failed to reject RFQ';
        return false;
      }
    } catch (e) {
      _error = 'Error rejecting RFQ: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

