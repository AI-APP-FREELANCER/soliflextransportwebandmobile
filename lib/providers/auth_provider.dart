import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _loadUserFromPrefs();
  }

  // Load user from shared preferences on app start
  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final fullName = prefs.getString('fullName');
      final department = prefs.getString('department');
      final role = prefs.getString('role');

      if (userId != null && fullName != null && department != null && role != null) {
        _user = UserModel(
          userId: userId,
          fullName: fullName,
          department: department,
          role: role,
        );
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      // Ignore errors on startup
    }
  }

  // Register a new user
  Future<bool> register({
    required String fullName,
    required String password,
    required String department,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.register(
        fullName: fullName,
        password: password,
        department: department,
      );

      if (result['success'] == true && result['user'] != null) {
        _user = result['user'] as UserModel;
        _isAuthenticated = true;
        await _saveUserToPrefs(_user!);
        _error = null;
        return true;
      } else {
        _error = result['message'] ?? 'Registration failed';
        return false;
      }
    } catch (e) {
      _error = 'Error during registration: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login user
  Future<bool> login({
    required String fullName,
    required String password,
    required String department,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.login(
        fullName: fullName,
        password: password,
        department: department,
      );

      if (result['success'] == true && result['user'] != null) {
        _user = result['user'] as UserModel;
        _isAuthenticated = true;
        await _saveUserToPrefs(_user!);
        _error = null;
        return true;
      } else {
        _error = result['message'] ?? 'Login failed';
        return false;
      }
    } catch (e) {
      _error = 'Error during login: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout user
  Future<void> logout() async {
    _user = null;
    _isAuthenticated = false;
    _error = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      // Ignore errors
    }
    
    notifyListeners();
  }

  // Save user to shared preferences
  Future<void> _saveUserToPrefs(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.userId);
      await prefs.setString('fullName', user.fullName);
      await prefs.setString('department', user.department);
      await prefs.setString('role', user.role);
    } catch (e) {
      // Ignore errors
    }
  }
}

