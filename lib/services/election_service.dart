import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/eleccion_pregunta.dart';
import '../models/enums.dart';
import '../models/opcion_voto.dart';

class ElectionService {
  final _client = Supabase.instance.client;

  Future<void> createFullElection({
    required Map<String, dynamic> eleccionData,
    required List<PreguntaCompleta> preguntasCompletas,
  }) async {
    try {
      final resEleccion = await _client
          .schema('votaciones')
          .from('elecciones')
          .insert(eleccionData)
          .select()
          .single();
      
      final String eleccionId = resEleccion['id'];

      for (var pc in preguntasCompletas) {
        final resPregunta = await _client
            .schema('votaciones')
            .from('preguntas')
            .insert({
              'eleccion_id': eleccionId,
              'texto_pregunta': pc.pregunta.textoPregunta,
              'tipo': pc.pregunta.tipo.toShortString(),
              'orden': pc.pregunta.orden,
            })
            .select()
            .single();
        
        final String preguntaId = resPregunta['id'];

        if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE && pc.opciones.isNotEmpty) {
          final opcionesMap = pc.opciones.map((o) => {
            'pregunta_id': preguntaId,
            'texto_opcion': o.textoOpcion,
            'valor': o.valor,
          }).toList();

          await _client.schema('votaciones').from('opciones').insert(opcionesMap);
        } else if (pc.pregunta.tipo == TipoPregunta.CANDIDATOS && pc.candidatesData != null) {
          final rows = pc.candidatesData!.map((c) => {
            'pregunta_id': preguntaId,
            'nombre_completo': c['nombre'],
            'dni': c['dni'],
            'sede': c['sede'],
            'postulacion': c['postulacion'], // Opcional
            'numero_candidatura': int.tryParse(c['numero'].toString()) ?? 0,
          }).toList();

          await _client.schema('votaciones').from('candidatos').insert(rows);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateElectionStatus(String electionId, EstadoEleccion nuevoEstado) async {
    await _client
        .schema('votaciones')
        .from('elecciones')
        .update({'estado': nuevoEstado.toShortString()})
        .eq('id', electionId);
  }

  Future<void> updateElectionDates(String electionId, DateTime inicio, DateTime fin) async {
    await _client
        .schema('votaciones')
        .from('elecciones')
        .update({
          'fecha_inicio': inicio.toIso8601String(),
          'fecha_fin': fin.toIso8601String(),
        })
        .eq('id', electionId);
  }

  Future<List<Eleccion>> getElections(String empresaId) async {
    final data = await _client
        .schema('votaciones')
        .from('elecciones')
        .select()
        .eq('empresa_id', empresaId)
        .order('created_at', ascending: false);
    
    return List<Eleccion>.from(data.map((x) => Eleccion.fromJson(x)));
  }

  Future<List<PreguntaCompleta>> getQuestionsByElection(String eleccionId) async {
    // 1. Obtener preguntas
    final dataPreguntas = await _client
        .schema('votaciones')
        .from('preguntas')
        .select()
        .eq('eleccion_id', eleccionId)
        .order('orden');
    
    final listaPreguntas = List<Pregunta>.from(dataPreguntas.map((x) => Pregunta.fromJson(x)));
    List<PreguntaCompleta> resultado = [];

    // 2. Obtener todas las opciones para estas preguntas en una sola consulta
    final idsPreguntas = listaPreguntas.map((p) => p.id).toList();
    if (idsPreguntas.isEmpty) return [];

    final dataOpciones = await _client
        .schema('votaciones')
        .from('opciones')
        .select()
        .filter('pregunta_id', 'in', idsPreguntas);
    
    print('DEBUG ELECTION: ID=${eleccionId}');
    print('DEBUG ELECTION: Opciones encontradas: ${dataOpciones.length} para preguntas: $idsPreguntas');
    
    final listaOpciones = List<Opcion>.from(dataOpciones.map((x) => Opcion.fromJson(x)));

    // 2.1. Obtener candidatos si hay preguntas de tipo CANDIDATOS
    // DEBUG: Verificando si se consulta la tabla
    final dataCandidatos = await _client
        .schema('votaciones')
        .from('candidatos')
        .select()
        .filter('pregunta_id', 'in', idsPreguntas);
    
    print('DEBUG ELECTION: Candidatos encontrados: ${dataCandidatos.length} para preguntas: $idsPreguntas');
    
    // print('DEBUG CANDIDATOS: ${dataCandidatos.length} encontrados para preguntas: $idsPreguntas');
    
    // Mapear candidatos a Opciones para que el frontend los pueda mostrar transparentemente
    final listaCandidatosComoOpciones = dataCandidatos.map((c) => Opcion(
      id: c['id'],
      preguntaId: c['pregunta_id'],
      textoOpcion: '${c['nombre_completo']} - ${c['numero_candidatura']}', // Formato visual
      valor: c['numero_candidatura'].toString(),
    )).toList();

    listaOpciones.addAll(listaCandidatosComoOpciones);

    // 3. Agrupar
    for (var p in listaPreguntas) {
      final opcionesDePregunta = listaOpciones.where((o) => o.preguntaId == p.id).toList();
      resultado.add(PreguntaCompleta(pregunta: p, opciones: opcionesDePregunta));
    }

    return resultado;
  }

  /// Fase 4: Obtener preguntas ACTIVAS que el usuario no ha votado
  Future<List<Map<String, dynamic>>> getPendingQuestionsForSocio(String usuarioId) async {
    final response = await _client.rpc('get_preguntas_pendientes', params: {
      'p_usuario_id': usuarioId,
    });
    
    final List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(response);
    
    // Fallback: Si el RPC no devuelve fechas (porque no se ha actualizado en BD), 
    // las buscamos manualmente para no bloquear la visualización al socio.
    if (questions.isNotEmpty && (questions.first['fecha_inicio'] == null || questions.first['titulo_eleccion'] == null)) {
      try {
        final electionIds = questions.map((q) => q['eleccion_id']).toSet().toList();
        final electionsData = await _client
            .schema('votaciones')
            .from('elecciones')
            .select('id, titulo, fecha_inicio, fecha_fin')
            .filter('id', 'in', electionIds);
        
        final Map<String, dynamic> electionMap = {
          for (var e in electionsData) e['id']: e
        };

        return questions.map((q) {
          final election = electionMap[q['eleccion_id']];
          return {
            ...q,
            'titulo_eleccion': election?['titulo'] ?? 'Elección',
            'fecha_inicio': election?['fecha_inicio'],
            'fecha_fin': election?['fecha_fin'],
          };
        }).toList();
      } catch (e) {
        debugPrint('Error en fallback de fechas: $e');
      }
    }
    
    return questions;
  }

  /// Fase 4: Emitir un voto atómico usando RPC
  Future<void> votar({
    required String usuarioId,
    required String preguntaId,
    String? empresaId,
    String? opcionId,
    double? valorNumerico,
  }) async {
    // Ya no buscamos currentUser aquí, confiamos en lo que manda el UI
    await _client.rpc('emitir_voto', params: {
      'p_usuario_id': usuarioId, 
      'p_pregunta_id': preguntaId,
      'p_empresa_id': empresaId,
      'p_opcion_id': opcionId,
      'p_valor_numerico': valorNumerico,
    });
  }

  /// Fase 4: Obtener historial de votos del usuario actual
  Future<List<Map<String, dynamic>>> getMyVoteHistory(String usuarioId) async {
    print('DEBUG: Solicitando historial para usuarioId=$usuarioId');
    try {
      final response = await _client.rpc('get_historial_votos', params: {
        'p_usuario_id': usuarioId,
      });
      print('DEBUG: Historial respuesta RAW length: ${(response as List).length}');
      print('DEBUG: Historial respuesta RAW data: $response');
      
      return List<Map<String, dynamic>>.from(response).map((row) {
        return {
          'id': row['id'],
          'timestamp': row['fecha_voto'],
          'preguntas': {'texto_pregunta': row['texto_pregunta']},
          'opciones': {
            'texto_opcion': row['texto_opcion'] ?? row['nombre_candidato'] ?? (row['valor_numerico']?.toString() ?? '-')
          },
          'valor_numerico': row['valor_numerico'],
        };
      }).toList();
    } catch (e) {
      print('DEBUG: Error en getMyVoteHistory: $e');
      rethrow;
    }
  }

  /// Fase 5: Obtener resultados agrupados (Anónimos)
  Future<List<Map<String, dynamic>>> getResultsByElection(String eleccionId) async {
    try {
      final response = await _client.rpc('get_resultados_conteo', params: {
        'p_eleccion_id': eleccionId,
      });
      
      // Mapear los campos del RPC para que coincidan con lo que espera el frontend
      // 'conteo' -> 'total_votos'
      // 'opcion_id' -> 'opcion_id' (sirve tanto para opciones como candidatos)
      return List<Map<String, dynamic>>.from(response).map((r) => {
        ...r,
        'total_votos': r['conteo'] ?? 0,
        'opcion_elegida_id': r['opcion_id'],
        'candidato_id': r['opcion_id'],
      }).toList();
    } catch (e) {
      print('DEBUG: Error en getResultsByElection: $e');
      return [];
    }
  }

  /// Fase 5: Reporte de Participación (Avance)
  Future<List<Map<String, dynamic>>> getParticipationReport(String eleccionId) async {
    try {
      final response = await _client.rpc('get_reporte_avance', params: {
        'p_eleccion_id': eleccionId,
      });
      
      return List<Map<String, dynamic>>.from(response).map((r) => {
        ...r,
        'usuario_id': r['user_id'],
        'nombre_usuario': r['nombre'] ?? 'Sin nombre',
        'ha_votado': r['estado'] != 'PENDIENTE',
        'fecha_voto': null, // El backend actual no devuelve fecha individual por ahora
      }).toList();
    } catch (e) {
      print('Error en getParticipationReport: $e');
      return [];
    }
  }

  /// Fase 5: Reporte de Resultados (Conteo)
  Future<List<Map<String, dynamic>>> getResultsReport(String eleccionId) async {
    final response = await _client.rpc('get_resultados_conteo', params: {
      'p_eleccion_id': eleccionId,
    });
    return List<Map<String, dynamic>>.from(response);
  }
  /// Fase (Extra): Editar elección (Agregar preguntas tardías)
  Future<void> addQuestionToElection({
    required String eleccionId,
    required PreguntaCompleta pc,
  }) async {
    // 1. Insertar Pregunta
    final resPregunta = await _client
        .schema('votaciones')
        .from('preguntas')
        .insert({
          'eleccion_id': eleccionId,
          'texto_pregunta': pc.pregunta.textoPregunta,
          'tipo': pc.pregunta.tipo.toShortString(),
          'orden': pc.pregunta.orden,
        })
        .select()
        .single();
    
    final String preguntaId = resPregunta['id'];

    // 2. Insertar Opciones si aplica
    if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE && pc.opciones.isNotEmpty) {
      final opcionesMap = pc.opciones.map((o) => {
        'pregunta_id': preguntaId,
        'texto_opcion': o.textoOpcion,
        'valor': o.valor,
      }).toList();

      await _client.schema('votaciones').from('opciones').insert(opcionesMap);
    }
  }

  /// Fase (Extra): Agregar pregunta de Candidatos con carga masiva
  Future<void> addQuestionWithCandidates({
    required String eleccionId,
    required String textoPregunta,
    required int orden,
    required List<Map<String, dynamic>> candidatosData,
  }) async {
    // 1. Insertar Pregunta
    final resPregunta = await _client
        .schema('votaciones')
        .from('preguntas')
        .insert({
          'eleccion_id': eleccionId,
          'texto_pregunta': textoPregunta,
          'tipo': 'CANDIDATOS', // Enum string
          'orden': orden,
        })
        .select()
        .single();
    
    final String preguntaId = resPregunta['id'];

    // 2. Insertar Candidatos
    if (candidatosData.isNotEmpty) {
      final rows = candidatosData.map((c) => {
        'pregunta_id': preguntaId,
        'nombre_completo': c['nombre'],
        'dni': c['dni'],
        'sede': c['sede'],
        'postulacion': c['postulacion'], // Opcional
        'numero_candidatura': int.tryParse(c['numero'].toString()) ?? 0,
      }).toList();

      await _client.schema('votaciones').from('candidatos').insert(rows);
    }
  }

  Future<void> deleteQuestion(String preguntaId) async {
    // Si la BD tiene ON DELETE CASCADE, esto borrará opciones y candidatos automáticamente.
    // Si no, habría que borrar hijos primero. Asumiremos CASCADE por consistencia con Supabase.
    await _client.schema('votaciones').from('preguntas').delete().eq('id', preguntaId);
  }

  Future<bool> hasVotes(String electionId) async {
    final results = await getResultsByElection(electionId);
    return results.any((r) => (r['total_votos'] ?? 0) > 0);
  }

  Future<void> deleteElection(String electionId) async {
    // Asumimos ON DELETE CASCADE en la base de datos para borrar preguntas, votos, etc.
    await _client.schema('votaciones').from('elecciones').delete().eq('id', electionId);
  }
}
