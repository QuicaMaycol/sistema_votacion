import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../models/perfil_empresa.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  Perfil? _currentProfile;
  bool _isLoading = false;
  String? _lastError;

  Perfil? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  
  // Autenticado si hay usuario de Supabase O si tenemos un perfil válido cargado (Modo DNI)
  bool get isAuthenticated => _authRepo.currentUser != null || _currentProfile != null;

  AuthProvider() {
    _authRepo.authStateChanges.listen((data) {
      if (data.session != null) {
        _checkUser();
      } else {
        // Si se cierra sesión en Supabase, también limpiamos local
        // A MENOS que estemos en modo DNI... pero logout debería limpiar todo.
        // Por seguridad, si auth state cambia a signout, limpiamos.
        if (data.event == AuthChangeEvent.signedOut) {
           _currentProfile = null;
           notifyListeners();
        }
      }
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

  Future<void> login(String input, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Intentar Login como Administrador (Email/Pass)
      // Si tiene @, asumimos que intenta ser admin o usa el formato email.
      if (input.contains('@')) {
         await _authRepo.signIn(email: input, password: password);
         await _checkUser(); // Carga perfil desde Auth
      } else {
         // 2. Si no tiene @, asumimos que es DNI.
         
         // VALIDACIÓN: Para socios, la contraseña debe ser su DNI.
         if (input != password) {
           throw Exception('Usuario o contraseña incorrectos.');
         }

         // Intentamos primero loguear como socio directo.
         final socioProfile = await _authRepo.loginWithDni(input);
         
         if (socioProfile != null) {
           _currentProfile = socioProfile;
           // NOTA: No hay sesión de Supabase Auth real, solo perfil en memoria.
         } else {
           throw Exception('DNI no encontrado o no habilitado para votar.');
         }
      }
    } catch (e) {
      _lastError = e.toString();
      // Si falló el login admin, y era un DNI, tal vez deberíamos haber probado el otro método?
      // Pero por ahora la distinción por '@' es robusta para este caso de uso.
      _currentProfile = null;
      debugPrint('Login Error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final userId = _currentProfile?.id;
    if (userId != null) {
      final authService = AuthService();
      await authService.removeHeartbeat(userId);
    }
    
    await _authRepo.signOut();
    _currentProfile = null;
    notifyListeners();
  }

  Future<void> recoverPassword(String email) async {
    try {
      await _authRepo.recoverPassword(email);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _authRepo.updatePassword(newPassword);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }
}
