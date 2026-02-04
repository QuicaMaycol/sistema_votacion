import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/opcion_voto.dart';

class VoteService {
  final _client = Supabase.instance.client;

  /// Obtiene las preguntas y opciones de una elección específica
  Future<List<Map<String, dynamic>>> getQuestionsWithOptions(String eleccionId) async {
    final data = await _client
        .schema('votaciones')
        .from('preguntas')
        .select('''
          id,
          texto_pregunta,
          tipo,
          opciones (
            id,
            texto_opcion,
            valor
          )
        ''')
        .eq('eleccion_id', eleccionId)
        .order('orden');
    
    return List<Map<String, dynamic>>.from(data);
  }

  /// Registra un voto
  Future<void> emitirVoto(Voto voto) async {
    await _client
        .schema('votaciones')
        .from('votos')
        .insert(voto.toJson());
  }

  /// Verifica si el usuario ya votó en una pregunta
  Future<bool> yaVoto(String usuarioId, String preguntaId) async {
    final data = await _client
        .schema('votaciones')
        .from('votos')
        .select()
        .eq('usuario_id', usuarioId)
        .eq('pregunta_id', preguntaId)
        .maybeSingle();
    
    return data != null;
  }

  /// Verifica si el usuario ha emitido algún voto en el sistema
  Future<bool> userHasVoted(String usuarioId) async {
    final data = await _client
        .schema('votaciones')
        .from('votos')
        .select('id')
        .eq('usuario_id', usuarioId)
        .limit(1)
        .maybeSingle();
    return data != null;
  }
}
