import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../services/election_service.dart';
import '../../models/eleccion_pregunta.dart';
import '../../models/opcion_voto.dart';

class VotingCard extends StatefulWidget {
  final Map<String, dynamic> preguntaData;
  final VoidCallback onVoted;

  const VotingCard({
    super.key, 
    required this.preguntaData, 
    required this.onVoted
  });

  @override
  State<VotingCard> createState() => _VotingCardState();
}

class _VotingCardState extends State<VotingCard> {
  final _electionService = ElectionService();
  final _numController = TextEditingController();
  bool _isVoting = false;
  List<Opcion> _opciones = [];
  bool _isLoadingOpciones = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  void _checkAndLoad() {
    final tipo = widget.preguntaData['tipo']?.toString().toUpperCase() ?? '';
    if (tipo == 'OPCION_MULTIPLE' || tipo == 'SI_NO' || tipo == 'BOLEANO') {
      _loadOpciones();
    }
  }

  Future<void> _loadOpciones() async {
    setState(() => _isLoadingOpciones = true);
    try {
      final eleccionId = widget.preguntaData['eleccion_id'] ?? widget.preguntaData['eleccionId'];
      final preguntaId = widget.preguntaData['id'];

      if (eleccionId == null || preguntaId == null) {
        throw 'Faltan IDs necesarios para cargar opciones';
      }

      final pc = await _electionService.getQuestionsByElection(eleccionId);
      final estaPregunta = pc.where((p) => p.pregunta.id == preguntaId).firstOrNull;
      
      if (estaPregunta != null && estaPregunta.opciones.isNotEmpty) {
        setState(() => _opciones = estaPregunta.opciones);
      } else {
        // Fallback: Si no hay opciones y el texto parece de SI/NO, crearlas localmente
        _tryFallbackOpciones();
      }
    } catch (e) {
      debugPrint('Error cargando opciones: $e');
      _tryFallbackOpciones();
    } finally {
      setState(() => _isLoadingOpciones = false);
    }
  }

  void _tryFallbackOpciones() {
    final texto = widget.preguntaData['texto_pregunta']?.toString().toLowerCase() ?? '';
    // Si no hay opciones, pero el texto pregunta "¿Desea...?" o "Considera...", asumimos Si/No
    if (_opciones.isEmpty) {
      setState(() {
        _opciones = [
          Opcion(id: 'AUTO_SI', preguntaId: widget.preguntaData['id'], textoOpcion: 'Sí'),
          Opcion(id: 'AUTO_NO', preguntaId: widget.preguntaData['id'], textoOpcion: 'No'),
        ];
      });
    }
  }

  Future<void> _votar(String? opcionId, double? valor) async {
    if (_isVoting) return;

    setState(() => _isVoting = true);
    try {
      // Si el id es generado automáticamente, necesitamos buscar el id real en la DB 
      // o manejar el error si el RPC falla por id inexistente.
      // Sin embargo, si llegamos aquí sin opciones reales, el voto podría fallar en la DB.
      await _electionService.votar(
        preguntaId: widget.preguntaData['id'],
        opcionId: (opcionId?.startsWith('AUTO_') ?? false) ? null : opcionId,
        valorNumerico: (opcionId == 'AUTO_SI') ? 1.0 : (opcionId == 'AUTO_NO' ? 0.0 : valor),
      );
      widget.onVoted(); 
    } catch (e) {
      debugPrint('Error al votar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos registrar tu voto: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.preguntaData['tipo']?.toString().toUpperCase() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7).withOpacity(0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.preguntaData['titulo_eleccion']?.toString().toUpperCase() ?? 'ELECCIÓN',
                      style: TextStyle(color: Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.preguntaData['texto_pregunta'] ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.black87),
              ),
              const SizedBox(height: 32),
              if (_isVoting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                  ),
                )
              else if (tipo == 'OPCION_MULTIPLE' || tipo == 'SI_NO')
                _buildMultipleChoice()
              else if (tipo == 'INPUT_NUMERICO')
                _buildNumericInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultipleChoice() {
    if (_isLoadingOpciones) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));

    return Column(
      children: _opciones.map((o) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            side: BorderSide(color: Colors.grey.shade200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _votar(o.id, null),
          child: Text(o.textoOpcion, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      )).toList(),
    );
  }

  Widget _buildNumericInput() {
    return Column(
      children: [
        TextField(
          controller: _numController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Ingrese un número',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () {
            final val = double.tryParse(_numController.text);
            if (val != null) {
              _votar(null, val);
            }
          },
          child: const Text('ENVIAR VOTO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
        ),
      ],
    );
  }
}
