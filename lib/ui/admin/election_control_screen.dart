import 'package:flutter/material.dart';
import '../../models/eleccion_pregunta.dart';
import '../../models/enums.dart';
import '../../services/election_service.dart';
import 'result_chart.dart';

class ElectionControlScreen extends StatefulWidget {
  final Eleccion eleccion;

  const ElectionControlScreen({super.key, required this.eleccion});

  @override
  State<ElectionControlScreen> createState() => _ElectionControlScreenState();
}

class _ElectionControlScreenState extends State<ElectionControlScreen> {
  final _electionService = ElectionService();
  late EstadoEleccion _estadoActual;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.eleccion.estado;
  }

  Future<void> _changeStatus(EstadoEleccion nuevoEstado) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cambio'),
        content: Text('¿Desea cambiar el estado de la elección a ${nuevoEstado.name.toUpperCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await _electionService.updateElectionStatus(widget.eleccion.id, nuevoEstado);
      setState(() => _estadoActual = nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Elección actualizada a ${nuevoEstado.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Control'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'CONTROL'),
              Tab(icon: Icon(Icons.bar_chart), text: 'RESULTADOS'),
              Tab(icon: Icon(Icons.people_outline), text: 'PARTICIPACIÓN'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildControlTab(),
            _buildResultsTab(),
            _buildParticipationTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 32),
          const Text('Estructura de la Elección', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          _buildQuestionsList(),
          const SizedBox(height: 32),
          const Text('Acciones de Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          const SizedBox(height: 16),
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return FutureBuilder<List<PreguntaCompleta>>(
      future: _electionService.getQuestionsByElection(widget.eleccion.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final preguntas = snapshot.data ?? [];
        if (preguntas.isEmpty) return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Esta elección no tiene preguntas cargadas.'),
        );

        return Column(
          children: preguntas.map((pc) => Card(
            margin: const EdgeInsets.only(top: 12),
            child: ExpansionTile(
              leading: CircleAvatar(child: Text((pc.pregunta.orden + 1).toString())),
              title: Text(pc.pregunta.textoPregunta, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Tipo: ${pc.pregunta.tipo.name}'),
              children: [
                if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE)
                  ...pc.opciones.map((o) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.radio_button_unchecked, size: 18),
                    title: Text(o.textoOpcion),
                  ))
                else if (pc.pregunta.tipo == TipoPregunta.INPUT_NUMERICO)
                  const ListTile(
                    dense: true,
                    leading: Icon(Icons.numbers, size: 18),
                    title: Text('Entrada numérica requerida'),
                  )
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.eleccion.titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.eleccion.descripcion ?? 'Sin descripción', style: const TextStyle(color: Colors.grey)),
            const Divider(height: 32),
            _infoRow(Icons.info_outline, 'Estado actual', _estadoActual.name.toUpperCase(), _getStatusColor(_estadoActual)),
            _infoRow(Icons.calendar_today, 'Inicio', widget.eleccion.fechaInicio.toString().split('.')[0]),
            _infoRow(Icons.calendar_today_outlined, 'Fin', widget.eleccion.fechaFin.toString().split('.')[0]),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    if (_isUpdating) return const Center(child: CircularProgressIndicator());

    if (_estadoActual == EstadoEleccion.BORRADOR) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _changeStatus(EstadoEleccion.ACTIVA),
        icon: const Icon(Icons.play_arrow),
        label: const Text('ACTIVAR ELECCIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    if (_estadoActual == EstadoEleccion.ACTIVA) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade800,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _changeStatus(EstadoEleccion.FINALIZADA),
        icon: const Icon(Icons.stop),
        label: const Text('FINALIZAR ELECCIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.blueGrey),
          SizedBox(width: 12),
          Text('ESTA ELECCIÓN HA FINALIZADO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Color _getStatusColor(EstadoEleccion estado) {
    switch (estado) {
      case EstadoEleccion.BORRADOR: return Colors.blue;
      case EstadoEleccion.ACTIVA: return Colors.green;
      case EstadoEleccion.FINALIZADA: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildResultsTab() {
    return FutureBuilder(
      future: Future.wait([
        _electionService.getQuestionsByElection(widget.eleccion.id),
        _electionService.getResultsByElection(widget.eleccion.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final List<PreguntaCompleta> preguntas = (snapshot.data![0] as List).cast<PreguntaCompleta>();
        final List<Map<String, dynamic>> resultados = (snapshot.data![1] as List).cast<Map<String, dynamic>>();

        if (resultados.isEmpty) return const Center(child: Text('Aún no hay votos registrados.'));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: preguntas.length,
          itemBuilder: (context, index) {
            final pc = preguntas[index];
            final resultadosDePregunta = resultados.where((r) => r['pregunta_id'] == pc.pregunta.id).toList();
            
            final opcionesMap = pc.opciones.map((o) => {
              'id': o.id,
              'texto_opcion': o.textoOpcion
            }).toList();

            return ResultChart(
              pregunta: pc.pregunta,
              resultados: resultadosDePregunta,
              opciones: opcionesMap,
            );
          },
        );
      },
    );
  }

  Widget _buildParticipationTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _electionService.getParticipationReport(widget.eleccion.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];

        int votaron = data.where((u) => u['ha_votado'] == true).length;
        int faltan = data.length - votaron;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCard('VOTARON', votaron.toString(), Colors.green),
                  _statCard('FALTAN', faltan.toString(), Colors.orange),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final u = data[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u['ha_votado'] ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Icon(
                        u['ha_votado'] ? Icons.check : Icons.person_outline,
                        color: u['ha_votado'] ? Colors.green : Colors.grey,
                      ),
                    ),
                    title: Text(u['nombre_usuario']),
                    subtitle: Text(u['ha_votado'] ? 'Votó el ${u['fecha_voto'].toString().split('T')[0]}' : 'Pendiente'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}
