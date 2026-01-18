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
    if (widget.preguntaData['tipo'] == 'OPCION_MULTIPLE') {
      _loadOpciones();
    }
  }

  Future<void> _loadOpciones() async {
    setState(() => _isLoadingOpciones = true);
    try {
      final pc = await _electionService.getQuestionsByElection(widget.preguntaData['eleccion_id']);
      final estaPregunta = pc.firstWhere((p) => p.pregunta.id == widget.preguntaData['id']);
      setState(() => _opciones = estaPregunta.opciones);
    } catch (e) {
      debugPrint('Error cargando opciones: $e');
    } finally {
      setState(() => _isLoadingOpciones = false);
    }
  }

  Future<void> _votar(String? opcionId, double? valor) async {
    setState(() => _isVoting = true);
    try {
      await _electionService.votar(
        preguntaId: widget.preguntaData['id'],
        opcionId: opcionId,
        valorNumerico: valor,
      );
      widget.onVoted(); // Notificar para animar y remover
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('Revise su conexión')) msg = 'Error de conexión';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.preguntaData['tipo'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.preguntaData['titulo_eleccion'] ?? 'Elección',
                style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.preguntaData['texto_pregunta'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_isVoting)
              const Center(child: CircularProgressIndicator())
            else if (tipo == 'OPCION_MULTIPLE')
              _buildMultipleChoice()
            else if (tipo == 'INPUT_NUMERICO')
              _buildNumericInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoice() {
    if (_isLoadingOpciones) return const LinearProgressIndicator();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _opciones.map((o) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.blue.shade300),
        ),
        onPressed: () => _votar(o.id, null),
        child: Text(o.textoOpcion, style: const TextStyle(fontWeight: FontWeight.bold)),
      )).toList(),
    );
  }

  Widget _buildNumericInput() {
    return Column(
      children: [
        TextField(
          controller: _numController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ingrese un número',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final val = double.tryParse(_numController.text);
            if (val != null) {
              _votar(null, val);
            }
          },
          child: const Text('ENVIAR VOTO', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
