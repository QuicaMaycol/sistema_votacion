import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class N8nService {
  // TODO: Reemplazar con la URL real del Webhook de n8n proporcionada por el usuario
  static const String _webhookUrl = 'https://TU_N8N_WEBHOOK_URL_AQUI';

  /// Envía los detalles del voto a n8n para procesar el envío de correo.
  Future<void> enviarConfirmacionVoto({
    required String socioNombre,
    required String socioEmail,
    required String eleccionTitulo,
    required String preguntaTexto,
    required String opcionElegida,
    String? valorNumerico,
  }) async {
    if (socioEmail.isEmpty || socioEmail.contains('@padron.votacion')) {
      debugPrint('N8nService: Socio sin correo válido o con correo ficticio. No se enviará confirmación.');
      return;
    }

    try {
      final payload = {
        'nombre_socio': socioNombre,
        'email_socio': socioEmail,
        'eleccion': eleccionTitulo,
        'pregunta': preguntaTexto,
        'opcion': opcionElegida,
        'valor': valorNumerico ?? 'N/A',
        'fecha': DateTime.now().toIso8601String(),
      };

      debugPrint('Enviando confirmación a n8n: $payload');

      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Confirmación enviada con éxito a n8n.');
      } else {
        debugPrint('Error al enviar a n8n (Status ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Excepción al enviar a n8n: $e');
    }
  }
}
