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
        // Provide user-friendly error messages
        String errorMessage = result['message'] ?? 'Failed to load departments';
        if (errorMessage.contains('502') || errorMessage.contains('Bad Gateway')) {
          errorMessage = 'Backend server is not responding. Please check if the server is running.';
        } else if (errorMessage.contains('Network error') || errorMessage.contains('Failed host lookup')) {
          errorMessage = 'Cannot connect to server. Please check your internet connection.';
        }
        _error = errorMessage;
        _departments = []; // Clear departments on error
      }
    } catch (e) {
      String errorMessage = 'Error loading departments: ${e.toString()}';
      if (errorMessage.contains('502') || errorMessage.contains('Bad Gateway')) {
        errorMessage = 'Backend server is not responding. Please check if the server is running.';
      } else if (errorMessage.contains('Network') || errorMessage.contains('Failed host lookup')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection.';
      }
      _error = errorMessage;
      _departments = []; // Clear departments on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

