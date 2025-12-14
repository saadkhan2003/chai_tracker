import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';

class AppProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();

  UserModel? _currentUser;
  GroupModel? _selectedGroup;
  List<GroupModel> _userGroups = [];
  bool _isLoading = false;
  bool _initialGroupsLoaded = false; // Track if groups have been fetched
  String? _error;

  // Getters
  UserModel? get currentUser => _currentUser;
  GroupModel? get selectedGroup => _selectedGroup;
  List<GroupModel> get userGroups => _userGroups;
  bool get isLoading => _isLoading;
  bool get initialGroupsLoaded => _initialGroupsLoaded;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get hasGroup => _selectedGroup != null;

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Set error
  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Initialize - check auth state
  Future<void> initialize() async {
    _isLoading = true; // Start loading
    notifyListeners();
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        _currentUser = await _authService.getUserById(user.uid);
        if (_currentUser != null) {
          _listenToUserGroups();
        }
      }
    } catch (e) {
      debugPrint('Error initializing: $e');
    } finally {
      _isLoading = false; // End loading
      notifyListeners();
    }
  }

  // Listen to user groups
  void _listenToUserGroups() {
    if (_currentUser == null) return;
    
    _groupService.getUserGroups(_currentUser!.id).listen((groups) {
      _userGroups = groups;
      _initialGroupsLoaded = true; // Mark groups as loaded
      // Auto-select first group if no group selected
      if (_selectedGroup == null && groups.isNotEmpty) {
        _selectedGroup = groups.first;
      }
      // Update selected group if it exists in list
      if (_selectedGroup != null) {
        final updated = groups.where((g) => g.id == _selectedGroup!.id).firstOrNull;
        if (updated != null) {
          _selectedGroup = updated;
        }
      }
      notifyListeners();
    });
  }

  // Register
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    _setLoading(true);
    _setError(null);
    
    try {
      _currentUser = await _authService.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      _setLoading(false);
      if (_currentUser != null) {
        _listenToUserGroups();
        return true;
      }
      _setError('Registration failed');
      return false;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    
    try {
      _currentUser = await _authService.login(
        email: email,
        password: password,
      );
      _setLoading(false);
      if (_currentUser != null) {
        _listenToUserGroups();
        return true;
      }
      _setError('Login failed');
      return false;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _selectedGroup = null;
    _userGroups = [];
    notifyListeners();
  }

  // Delete Account
  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      await _authService.deleteAccount();
      _currentUser = null;
      _selectedGroup = null;
      _userGroups = [];
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Create group
  Future<bool> createGroup(String name) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      final group = await _groupService.createGroup(
        name: name,
        adminId: _currentUser!.id,
      );
      _selectedGroup = group;
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  // Join group
  Future<bool> joinGroup(String code) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _setError(null);
    
    try {
      final group = await _groupService.joinGroup(
        code: code,
        userId: _currentUser!.id,
      );
      if (group != null) {
        _selectedGroup = group;
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return false;
    }
  }

  // Select group
  void selectGroup(GroupModel group) {
    _selectedGroup = group;
    notifyListeners();
  }

  // Get user name by ID
  Future<String> getUserName(String userId) async {
    final user = await _authService.getUserById(userId);
    return user?.name ?? 'Unknown';
  }

  // Get users map
  Future<Map<String, UserModel>> getUsersById(List<String> userIds) async {
    return await _authService.getUsersByIds(userIds);
  }

  // Refresh current user data
  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      _currentUser = await _authService.getUserById(_currentUser!.id);
      notifyListeners();
    }
  }

  // Refresh groups (and reset selected if it was deleted)
  Future<void> refreshGroups() async {
    // The stream listener will auto-update groups
    // But we need to check if selected group still exists
    if (_selectedGroup != null) {
      final exists = _userGroups.any((g) => g.id == _selectedGroup!.id);
      if (!exists) {
        _selectedGroup = _userGroups.isNotEmpty ? _userGroups.first : null;
      }
    }
    notifyListeners();
  }

  // Refresh all data from Firebase
  Future<void> refreshAll() async {
    if (_currentUser == null) return;
    
    try {
      // Refresh user data
      _currentUser = await _authService.getUserById(_currentUser!.id);
      
      // Re-subscribe to groups (this will trigger fresh data)
      _listenToUserGroups();
      
      // Small delay to allow stream to emit
      await Future.delayed(const Duration(milliseconds: 500));
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing: $e');
    }
  }
}
