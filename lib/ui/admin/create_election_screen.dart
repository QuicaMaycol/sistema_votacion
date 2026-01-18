import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/eleccion_pregunta.dart';
import '../../models/enums.dart';
import '../../models/opcion_voto.dart';
import '../../services/election_service.dart';
import '../../providers/auth_provider.dart';

class CreateElectionScreen extends StatefulWidget {
  const CreateElectionScreen({super.key});

  @override
  State<CreateElectionScreen> createState() => _CreateElectionScreenState();
}

class _CreateElectionScreenState extends State<CreateElectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _electionService = ElectionService();

  final _tituloController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 1));

  final List<PreguntaCompleta> _preguntas = [];
  bool _isSaving = false;

  void _addPregunta() {
    setState(() {
      _preguntas.add(PreguntaCompleta(
        pregunta: Pregunta(
          id: '',
          eleccionId: '',
          textoPregunta: '',
          tipo: TipoPregunta.OPCION_MULTIPLE,
          orden: _preguntas.length,
        ),
        opciones: [],
      ));
    });
  }

  void _removePregunta(int index) {
    setState(() {
      _preguntas.removeAt(index);
      // Re-ordenar las preguntas restantes para que no haya saltos
      for (int i = 0; i < _preguntas.length; i++) {
        _preguntas[i].pregunta = Pregunta(
          id: '',
          eleccionId: '',
          textoPregunta: _preguntas[i].pregunta.textoPregunta,
          tipo: _preguntas[i].pregunta.tipo,
          orden: i,
        );
      }
    });
  }

  void _addOpcion(int preguntaIndex) {
    setState(() {
      _preguntas[preguntaIndex].opciones.add(Opcion(
        id: '',
        preguntaId: '',
        textoOpcion: '',
      ));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preguntas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añada al menos una pregunta')),
      );
      return;
    }

    final empresaId = context.read<AuthProvider>().currentProfile?.empresaId;
    if (empresaId == null) return;

    setState(() => _isSaving = true);
    try {
      await _electionService.createFullElection(
        eleccionData: {
          'empresa_id': empresaId,
          'titulo': _tituloController.text,
          'descripcion': _descController.text,
          'fecha_inicio': _fechaInicio.toIso8601String(),
          'fecha_fin': _fechaFin.toIso8601String(),
          'estado': EstadoEleccion.BORRADOR.toShortString(),
        },
        preguntasCompletas: _preguntas,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Failed to fetch') || errorMsg.contains('ClientException')) {
          errorMsg = 'Revise su conexión a internet.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $errorMsg')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Elección'),
        actions: [
          if (!_isSaving)
            IconButton(onPressed: _save, icon: const Icon(Icons.save))
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título de la Elección'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              const Text('Preguntas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ...List.generate(_preguntas.length, (pIdx) => _buildPreguntaItem(pIdx)),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _addPregunta,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Añadir Pregunta'),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreguntaItem(int pIdx) {
    final pc = _preguntas[pIdx];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(labelText: 'Pregunta ${pIdx + 1}'),
                    onChanged: (v) => _preguntas[pIdx].pregunta = Pregunta(
                      id: '',
                      eleccionId: '',
                      textoPregunta: v,
                      tipo: pc.pregunta.tipo,
                      orden: pIdx,
                    ),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                ),
                DropdownButton<TipoPregunta>(
                  value: pc.pregunta.tipo,
                  onChanged: (v) => setState(() => _preguntas[pIdx].pregunta = Pregunta(
                    id: '',
                    eleccionId: '',
                    textoPregunta: pc.pregunta.textoPregunta,
                    tipo: v!,
                    orden: pIdx,
                  )),
                  items: TipoPregunta.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.toShortString()),
                  )).toList(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removePregunta(pIdx),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Eliminar Pregunta',
                ),
              ],
            ),
            if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE) ...[
              const SizedBox(height: 8),
              const Text('Opciones:'),
              ...List.generate(pc.opciones.length, (oIdx) => Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(hintText: 'Opción ${oIdx + 1}'),
                        onChanged: (v) => pc.opciones[oIdx] = Opcion(
                          id: '',
                          preguntaId: '',
                          textoOpcion: v,
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() => pc.opciones.removeAt(oIdx)),
                    )
                  ],
                ),
              )),
              TextButton.icon(
                onPressed: () => _addOpcion(pIdx),
                icon: const Icon(Icons.add),
                label: const Text('Añadir Opción'),
              )
            ]
          ],
        ),
      ),
    );
  }
}
