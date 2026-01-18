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
        .inFilter('pregunta_id', idsPreguntas);
    
    final listaOpciones = List<Opcion>.from(dataOpciones.map((x) => Opcion.fromJson(x)));

    // 3. Agrupar
    for (var p in listaPreguntas) {
      final opcionesDePregunta = listaOpciones.where((o) => o.preguntaId == p.id).toList();
      resultado.add(PreguntaCompleta(pregunta: p, opciones: opcionesDePregunta));
    }

    return resultado;
  }

  /// Fase 4: Obtener preguntas ACTIVAS que el usuario no ha votado
  Future<List<Map<String, dynamic>>> getPendingQuestionsForSocio() async {
    final response = await _client.rpc('get_preguntas_pendientes');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fase 4: Emitir un voto atómico usando RPC
  Future<void> votar({
    required String preguntaId,
    String? opcionId,
    double? valorNumerico,
  }) async {
    await _client.rpc('emitir_voto', params: {
      'p_pregunta_id': preguntaId,
      'p_opcion_id': opcionId,
      'p_valor_numerico': valorNumerico,
    });
  }

  /// Fase 4: Obtener historial de votos del usuario actual
  Future<List<Map<String, dynamic>>> getMyVoteHistory() async {
    final data = await _client
        .schema('votaciones')
        .from('votos')
        .select('''
          id,
          timestamp,
          preguntas (texto_pregunta),
          opciones (texto_opcion),
          valor_numerico
        ''')
        .eq('usuario_id', _client.auth.currentUser!.id)
        .order('timestamp', ascending: false);
    
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fase 5: Obtener resultados agrupados (Anónimos)
  Future<List<Map<String, dynamic>>> getResultsByElection(String eleccionId) async {
    final data = await _client
        .schema('votaciones')
        .from('view_resultados_conteo')
        .select()
        .eq('pregunta_id', eleccionId); // Nota: El SQL de la vista agrupa por pregunta
    
    // Si la vista filtra por pregunta_id, pero se le pasa el ID de la elección, 
    // necesitamos filtrar por las preguntas de esa elección.
    // ACTUALIZACIÓN: La vista 'view_resultados_conteo' agrupa por pregunta_id.
    // Necesitamos obtener los IDs de las preguntas de esta elección primero.
    final preguntas = await _client
        .schema('votaciones')
        .from('preguntas')
        .select('id')
        .eq('eleccion_id', eleccionId);
    
    final idsPreguntas = preguntas.map((p) => p['id']).toList();
    
    final results = await _client
        .schema('votaciones')
        .from('view_resultados_conteo')
        .select()
        .inFilter('pregunta_id', idsPreguntas);

    return List<Map<String, dynamic>>.from(results);
  }

  /// Fase 5: Reporte de Participación
  Future<List<Map<String, dynamic>>> getParticipationReport(String eleccionId) async {
    final response = await _client.rpc('get_reporte_participacion', params: {
      'p_eleccion_id': eleccionId,
    });
    return List<Map<String, dynamic>>.from(response);
  }
}
