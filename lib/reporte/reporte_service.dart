import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/enums.dart';

class ReporteService {
  final _client = Supabase.instance.client;

  /// Obtiene la lista completa de socios de una empresa y su estado de votación en una elección.
  Future<List<Map<String, dynamic>>> getParticipacionDetallada(String empresaId, String eleccionId) async {
    try {
      // 1. Obtener todos los socios de la empresa
      final sociosData = await _client
          .schema('votaciones')
          .from('perfiles')
          .select('id, nombre, dni, email, rol')
          .eq('empresa_id', empresaId)
          .eq('rol', RolUsuario.SOCIO.toShortString());

      // 2. Obtener los IDs de las preguntas de la elección para filtrar votos
      final preguntasData = await _client
          .schema('votaciones')
          .from('preguntas')
          .select('id')
          .eq('eleccion_id', eleccionId);
      
      final List<String> idsPreguntas = List<String>.from(preguntasData.map((p) => p['id']));

      if (idsPreguntas.isEmpty) {
        return sociosData.map((s) => {...s, 'ha_votado': false, 'votos_realizados': 0}).toList();
      }

      // 3. Obtener votos registrados para estas preguntas
      final votosData = await _client
          .schema('votaciones')
          .from('votos')
          .select('usuario_id, pregunta_id')
          .filter('pregunta_id', 'in', idsPreguntas);

      // 4. Mapear participación
      final mapVotosPorUsuario = <String, Set<String>>{};
      for (var v in votosData) {
        final uid = v['usuario_id'];
        final pid = v['pregunta_id'];
        if (!mapVotosPorUsuario.containsKey(uid)) mapVotosPorUsuario[uid] = {};
        mapVotosPorUsuario[uid]!.add(pid);
      }

      return sociosData.map((socio) {
        final userId = socio['id'];
        final votosRealizados = mapVotosPorUsuario[userId]?.length ?? 0;
        final totalEsperado = idsPreguntas.length;

        return {
          ...socio,
          'votos_realizados': votosRealizados,
          'total_preguntas': totalEsperado,
          'ha_votado': votosRealizados > 0,
          'completo': votosRealizados >= totalEsperado,
        };
      }).toList();
    } catch (e) {
      print('Error en getParticipacionDetallada: $e');
      rethrow;
    }
  }

  /// Obtiene resultados agrupados por sede para tipos de pregunta CANDIDATOS.
  Future<Map<String, List<Map<String, dynamic>>>> getResultadosPorSede(String eleccionId) async {
    try {
      // Usamos el RPC existente para el conteo base si es posible, 
      // o calculamos manualmente para incluir la sede del candidato.
      
      // 1. Obtener candidatos de la elección (a través de sus preguntas)
      final candidatosData = await _client
          .schema('votaciones')
          .from('candidatos')
          .select('''
            id, 
            nombre_completo, 
            sede, 
            numero_candidatura,
            preguntas!inner(eleccion_id)
          ''')
          .eq('preguntas.eleccion_id', eleccionId);

      // 2. Obtener conteo de votos
      final resultadosConteos = await _client.rpc('get_resultados_conteo', params: {
        'p_eleccion_id': eleccionId,
      });

      final mapConteos = {
        for (var r in resultadosConteos) r['opcion_id'] ?? r['candidato_id']: r['conteo'] ?? 0
      };

      // 3. Agrupar por sede
      final resultadosPorSede = <String, List<Map<String, dynamic>>>{};

      for (var cand in candidatosData) {
        final sede = cand['sede'] ?? 'Sin Sede';
        if (!resultadosPorSede.containsKey(sede)) {
          resultadosPorSede[sede] = [];
        }

        final votos = mapConteos[cand['id']] ?? 0;
        
        resultadosPorSede[sede]!.add({
          'id': cand['id'],
          'nombre': cand['nombre_completo'],
          'numero': cand['numero_candidatura'],
          'votos': votos,
        });
      }

      // Ordenar cada sede por votos descendente
      resultadosPorSede.forEach((sede, lista) {
        lista.sort((a, b) => b['votos'].compareTo(a['votos']));
      });

      return resultadosPorSede;
    } catch (e) {
      print('Error en getResultadosPorSede: $e');
      rethrow;
    }
  }
}
