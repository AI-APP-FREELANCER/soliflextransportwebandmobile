import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DepartmentProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<String> _departments = [];
  bool _isLoading = false;
  String? _error;

  List<String> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDepartments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getDepartments();
      if (result['success'] == true) {
        _departments = result['departments'] as List<String>;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load departments';
      }
    } catch (e) {
      _error = 'Error loading departments: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

