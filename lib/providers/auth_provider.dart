import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../models/perfil_empresa.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  Perfil? _currentProfile;
  bool _isLoading = false;
  String? _lastError;

  Perfil? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isAuthenticated => _authRepo.currentUser != null;

  AuthProvider() {
    _authRepo.authStateChanges.listen((data) {
      _checkUser();
    });
    _checkUser();
  }

  Future<void> _checkUser() async {
    if (_authRepo.currentUser == null) {
      _currentProfile = null;
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    
    try {
      _currentProfile = await _authRepo.getMyProfile();
      debugPrint('DEBUG: Perfil cargado exitosamente: ${_currentProfile?.nombre}');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('ERROR CRÍTICO en _checkUser: $_lastError');
      _currentProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepo.signIn(email: email, password: password);
      await _checkUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authRepo.signOut();
    _currentProfile = null;
    notifyListeners();
  }
}
