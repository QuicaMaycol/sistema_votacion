class Opcion {
  final String id;
  final String preguntaId;
  final String textoOpcion;
  final String? valor;

  Opcion({
    required this.id,
    required this.preguntaId,
    required this.textoOpcion,
    this.valor,
  });

  factory Opcion.fromJson(Map<String, dynamic> json) {
    return Opcion(
      id: json['id'],
      preguntaId: json['pregunta_id'],
      textoOpcion: json['texto_opcion'],
      valor: json['valor'],
    );
  }

  Map<String, dynamic> toJson() => {
        'pregunta_id': preguntaId,
        'texto_opcion': textoOpcion,
        'valor': valor,
      };
}

class Voto {
  final String? id;
  final String preguntaId;
  final String usuarioId;
  final String? opcionElegidaId;
  final double? valorNumerico;
  final DateTime? timestamp;

  Voto({
    this.id,
    required this.preguntaId,
    required this.usuarioId,
    this.opcionElegidaId,
    this.valorNumerico,
    this.timestamp,
  });

  factory Voto.fromJson(Map<String, dynamic> json) {
    return Voto(
      id: json['id'],
      preguntaId: json['pregunta_id'],
      usuarioId: json['usuario_id'],
      opcionElegidaId: json['opcion_elegida_id'],
      valorNumerico: json['valor_numerico']?.toDouble(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'pregunta_id': preguntaId,
        'usuario_id': usuarioId,
        'opcion_elegida_id': opcionElegidaId,
        'valor_numerico': valorNumerico,
      };
}
