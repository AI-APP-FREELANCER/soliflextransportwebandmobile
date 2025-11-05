import 'package:flutter/foundation.dart';
import '../models/vendor_model.dart';
import '../services/api_service.dart';

class VendorProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<VendorModel> _vendors = [];
  bool _isLoading = false;
  String? _error;

  List<VendorModel> get vendors => _vendors;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadVendors() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getVendors();
      if (result['success'] == true) {
        _vendors = result['vendors'] as List<VendorModel>;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load vendors';
      }
    } catch (e) {
      _error = 'Error loading vendors: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

