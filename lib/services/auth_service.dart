import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../models/perfil_empresa.dart';
import '../models/enums.dart';

class AuthService {
  final AuthRepository _authRepo = AuthRepository();
  final _client = Supabase.instance.client;

  /// Lista todas las empresas para el registro de socios
  Future<List<Map<String, dynamic>>> getEmpresasList() async {
    final data = await _client
        .schema('votaciones')
        .from('empresas')
        .select('id, nombre')
        .order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Busca una empresa por su RUC
  Future<Map<String, dynamic>?> buscarEmpresaPorRuc(String ruc) async {
    final data = await _client
        .schema('votaciones')
        .from('empresas')
        .select('id, nombre, ruc')
        .eq('ruc', ruc)
        .maybeSingle();
    return data;
  }

  /// REGISTRO DE SOCIO (Afiliación a empresa existente)
  Future<String> registerSocio({
    required String email,
    required String password,
    required String nombre,
    required String dni,
    required String empresaId,
  }) async {
    try {
      // 1. Intentar registrar en Auth (si el usuario es nuevo)
      await _authRepo.signUp(
        email: email,
        password: password,
        metadata: {
          'sistema': 'votaciones',
          'nombre': nombre,
          'empresa_id': empresaId,
          'dni': dni,
          'rol': RolUsuario.SOCIO.toShortString(),
          'estado_acceso': EstadoUsuario.PENDIENTE.toShortString(),
        },
      );

      // 2. FORZAR VINCULACIÓN (Por si el usuario ya existía en Auth de otro sistema)
      await _client.rpc('vincular_usuario_a_sistema', params: {
        'p_email': email,
        'p_metadata': {
          'sistema': 'votaciones',
          'nombre': nombre,
          'empresa_id': empresaId,
          'dni': dni,
          'rol': RolUsuario.SOCIO.toShortString(),
          'estado_acceso': EstadoUsuario.PENDIENTE.toShortString(),
        },
      });
      
      return '¡Registro casi completado! Hemos enviado un enlace de confirmación a su correo. Por favor, revise su bandeja de entrada y la carpeta de SPAM. Debe hacer clic en el enlace para activar su cuenta. Si ya tiene cuenta en otro de nuestros sistemas, intente iniciar sesión directamente.';
    } catch (e) {
      rethrow;
    }
  }

  /// REGISTRO DE EMPRESA (Nueva suscripción SaaS)
  Future<String> registerEmpresa({
    required String nombreEmpresa,
    required String ruc,
    required String adminEmail,
    required String adminPassword,
    required String adminNombre,
    required String adminCelular,
  }) async {
    try {
      // 0. Validar si el RUC ya existe
      final empresaExistente = await buscarEmpresaPorRuc(ruc);
      if (empresaExistente != null) {
        throw 'El RUC $ruc ya se encuentra registrado para la empresa ${empresaExistente['nombre']}.';
      }

      // 1. Crear la empresa primero (temporalmente)
      final resEmpresa = await _client
          .schema('votaciones')
          .from('empresas')
          .insert({
            'nombre': nombreEmpresa,
            'ruc': ruc,
          })
          .select()
          .single();
      
      final String empresaId = resEmpresa['id'];

      try {
        // 2. Registrar/Vincular usuario
        final authRes = await _authRepo.signUp(
          email: adminEmail,
          password: adminPassword,
          metadata: {
            'sistema': 'votaciones',
            'nombre': adminNombre,
            'empresa_id': empresaId,
            'celular': adminCelular,
            'rol': RolUsuario.ADMIN.toShortString(),
            'estado_acceso': EstadoUsuario.ACTIVO.toShortString(),
          },
        );

        await _client.rpc('vincular_usuario_a_sistema', params: {
          'p_email': adminEmail,
          'p_metadata': {
            'sistema': 'votaciones',
            'nombre': adminNombre,
            'empresa_id': empresaId,
            'celular': adminCelular,
            'rol': RolUsuario.ADMIN.toShortString(),
            'estado_acceso': EstadoUsuario.ACTIVO.toShortString(),
          },
        });

        // 3. VERIFICACIÓN CRÍTICA: ¿Se creó el perfil?
        // Usamos un RPC porque si la confirmación de email está activa, el usuario
        // no tiene sesión aún y el RLS le impediría leer su propio perfil con un SELECT.
        await Future.delayed(const Duration(seconds: 1)); // Un segundo para seguridad
        
        final userId = authRes.user?.id;
        if (userId != null) {
          final bool existe = await _client.rpc('verificar_perfil_creado', params: {
            'u_id': userId,
          });
            
          if (!existe) {
            throw 'No se pudo confirmar la creación del perfil (Timeout/Trigger failure). Operación cancelada.';
          }
        }
        
        return '¡Registro casi completado! Hemos enviado un enlace de confirmación a su correo. Por favor, revise su bandeja de entrada y la carpeta de SPAM. Debe hacer clic en el enlace para activar su cuenta. Si ya tiene cuenta en otro de nuestros sistemas, intente iniciar sesión directamente.';

      } catch (e) {
        // ROLLBACK: Borrar la empresa si algo falla (auth, rpc o perfil)
        await _client.schema('votaciones').from('empresas').delete().eq('id', empresaId);
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- MÉTODOS ADMINISTRATIVOS ---

  /// Obtiene los usuarios con estado PENDIENTE de la empresa actual
  Future<List<Map<String, dynamic>>> getPendingUsers(String empresaId) async {
    final data = await _client
        .schema('votaciones')
        .from('perfiles')
        .select()
        .eq('empresa_id', empresaId)
        .eq('estado_acceso', 'PENDIENTE')
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Obtiene todos los socios activos/rechazados de la empresa
  Future<List<Map<String, dynamic>>> getSocioList(String empresaId) async {
    final data = await _client
        .schema('votaciones')
        .from('perfiles')
        .select()
        .eq('empresa_id', empresaId)
        .neq('rol', 'ADMIN') // No mostrar administradores en la lista de socios
        .order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Aprueba o rechaza una solicitud de acceso
  Future<void> updateEstadoAcceso(String userId, EstadoUsuario nuevoEstado) async {
    await _client
        .schema('votaciones')
        .from('perfiles')
        .update({'estado_acceso': nuevoEstado.toShortString()})
        .eq('id', userId);
  }

  // --- GESTIÓN DE EQUIPO (ADMIN) ---

  Future<void> createStaffUser({
    required String email,
    required String password,
    required String nombre,
    required String dni,
    required RolUsuario rol,
  }) async {
    try {
      await _client.rpc('crear_usuario_equipo', params: {
        'p_email': email,
        'p_password': password,
        'p_nombre': nombre,
        'p_dni': dni,
        'p_rol': rol.name,
      });
    } catch (e) {
      debugPrint('Error creando usuario de equipo: $e');
      throw 'Error al crear el usuario: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getStaffList(String empresaId) async {
    final data = await _client
        .schema('votaciones')
        .from('perfiles')
        .select()
        .eq('empresa_id', empresaId)
        .inFilter('rol', ['ADMIN', 'GERENCIA'])
        .order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }
}
