import 'enums.dart';
import 'opcion_voto.dart';

class Eleccion {
  final String id;
  final String empresaId;
  final String titulo;
  final String? descripcion;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final EstadoEleccion estado;
  final DateTime createdAt;

  Eleccion({
    required this.id,
    required this.empresaId,
    required this.titulo,
    this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.createdAt,
  });

  factory Eleccion.fromJson(Map<String, dynamic> json) {
    return Eleccion(
      id: json['id'],
      empresaId: json['empresa_id'],
      titulo: json['titulo'],
      descripcion: json['descripcion'],
      fechaInicio: DateTime.parse(json['fecha_inicio']),
      fechaFin: DateTime.parse(json['fecha_fin']),
      estado: EstadoEleccion.values.firstWhere((e) => e.toShortString() == json['estado']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'empresa_id': empresaId,
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin.toIso8601String(),
        'estado': estado.toShortString(),
      };
}

class Pregunta {
  final String id;
  final String eleccionId;
  final String textoPregunta;
  final TipoPregunta tipo;
  final int orden;

  Pregunta({
    required this.id,
    required this.eleccionId,
    required this.textoPregunta,
    required this.tipo,
    required this.orden,
  });

  factory Pregunta.fromJson(Map<String, dynamic> json) {
    return Pregunta(
      id: json['id'],
      eleccionId: json['eleccion_id'],
      textoPregunta: json['texto_pregunta'],
      tipo: TipoPregunta.values.firstWhere((e) => e.toShortString() == json['tipo']),
      orden: json['orden'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'texto_pregunta': textoPregunta,
        'tipo': tipo.toShortString(),
        'orden': orden,
      };
}

class PreguntaCompleta {
  Pregunta pregunta;
  List<Opcion> opciones;

  PreguntaCompleta({
    required this.pregunta,
    this.opciones = const [],
  });
}
