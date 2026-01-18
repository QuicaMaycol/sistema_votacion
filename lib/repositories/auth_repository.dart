import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/perfil_empresa.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    return await _client.auth.signUp(email: email, password: password, data: metadata);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Perfil?> getMyProfile() async {
    final user = currentUser;
    if (user == null) {
      debugPrint('DEBUG: getMyProfile - No hay usuario autenticado');
      return null;
    }

    try {
      debugPrint('DEBUG: Buscando perfil para UID: ${user.id}');
      final data = await _client
          .schema('votaciones')
          .from('perfiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      if (data == null) {
        debugPrint('WARNING: No se encontró fila en perfiles para el ID: ${user.id}. ¿Está el trigger funcionando?');
        return null;
      }

      debugPrint('DEBUG: Datos recibidos de perfiles: $data');
      return Perfil.fromJson(data);
    } catch (e) {
      debugPrint('ERROR en getMyProfile Repository: $e');
      rethrow;
    }
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
