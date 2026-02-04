import 'package:flutter/foundation.dart';
import 'enums.dart';

class Empresa {
  final String id;
  final String nombre;
  final String ruc;
  final String? logoUrl;
  final DateTime createdAt;

  Empresa({
    required this.id,
    required this.nombre,
    required this.ruc,
    this.logoUrl,
    required this.createdAt,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      id: json['id'],
      nombre: json['nombre'],
      ruc: json['ruc'],
      logoUrl: json['logo_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'ruc': ruc,
        'logo_url': logoUrl,
      };
}

class Perfil {
  final String id;
  final String empresaId;
  final String nombre;
  final String? email; // NUEVO
  final String? dni;
  final String? celular;
  final RolUsuario rol;
  final EstadoUsuario estadoAcceso;
  final DateTime createdAt;

  Perfil({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.email,
    this.dni,
    this.celular,
    required this.rol,
    required this.estadoAcceso,
    required this.createdAt,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    try {
      return Perfil(
        id: json['id'],
        empresaId: json['empresa_id'],
        nombre: json['nombre'],
        email: json['email'],
        dni: json['dni'],
        celular: json['celular'],
        rol: RolUsuario.values.firstWhere(
          (e) => e.toShortString() == json['rol'],
          orElse: () => throw 'Rol desconocido: ${json['rol']}',
        ),
        estadoAcceso: EstadoUsuario.values.firstWhere(
          (e) => e.toShortString() == json['estado_acceso'],
          orElse: () => throw 'Estado desconocido: ${json['estado_acceso']}',
        ),
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at']) 
            : DateTime.now(),
      );
    } catch (e) {
      debugPrint('ERROR PARSEANDO PERFIL JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'empresa_id': empresaId,
        'nombre': nombre,
        'email': email,
        'dni': dni,
        'celular': celular,
        'rol': rol.toShortString(),
        'estado_acceso': estadoAcceso.toShortString(),
      };
}
