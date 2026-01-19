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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFD),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            widget.eleccion.titulo,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: isMobile ? 'Control' : 'Panel de Control'),
              Tab(text: isMobile ? 'Votos' : 'Resultados en Vivo'),
              Tab(text: isMobile ? 'Usuarios' : 'Participación'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildControlTab(isMobile),
            _buildResultsTab(),
            _buildParticipationTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlTab(bool isMobile) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 40),
              const Text(
                'Estructura de la Elección', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)
              ),
              const SizedBox(height: 16),
              _buildQuestionsList(),
              const SizedBox(height: 48),
              const Text(
                'Acciones de Gestión', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)
              ),
              const SizedBox(height: 20),
              _buildControlButtons(),
              const SizedBox(height: 40),
            ],
          ),
        ),
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
          child: Text('Esta elección no tiene preguntas cargadas.', style: TextStyle(color: Colors.grey)),
        );

        return Column(
          children: preguntas.map((pc) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: Center(child: Text((pc.pregunta.orden + 1).toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                ),
                title: Text(pc.pregunta.textoPregunta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text('Tipo: ${pc.pregunta.tipo.name}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Column(
                      children: [
                        if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE)
                          ...pc.opciones.map((o) => Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(Icons.radio_button_unchecked, size: 16, color: Colors.blueAccent),
                              title: Text(o.textoOpcion, style: const TextStyle(fontSize: 13)),
                            ),
                          ))
                        else if (pc.pregunta.tipo == TipoPregunta.INPUT_NUMERICO)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: const Row(
                              children: [
                                Icon(Icons.numbers, size: 16, color: Colors.blueAccent),
                                SizedBox(width: 12),
                                Text('Entrada numérica requerida', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          )
                      ],
                    ),
                  )
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DETALLES GENERALES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.2)),
                _statusBadge(_estadoActual),
              ],
            ),
            const SizedBox(height: 20),
            Text(widget.eleccion.titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(widget.eleccion.descripcion ?? 'Sin descripción', style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
            const Divider(height: 48, color: Color(0xFFF5F5F7)),
            Row(
              children: [
                Expanded(child: _infoItem(Icons.calendar_today_rounded, 'Inicio', widget.eleccion.fechaInicio.toString().split('.')[0])),
                Expanded(child: _infoItem(Icons.calendar_today_outlined, 'Fin', widget.eleccion.fechaFin.toString().split('.')[0])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(EstadoEleccion estado) {
    Color color = _getStatusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(estado.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
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
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)),
        child: Column(
          children: [
            const Text('Esta elección está en modo borrador. Los socios no pueden verla ni votar aún.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.green)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _changeStatus(EstadoEleccion.ACTIVA),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ACTIVAR ELECCIÓN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }

    if (_estadoActual == EstadoEleccion.ACTIVA) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100)),
        child: Column(
          children: [
            const Text('La elección está en curso. Al finalizarla, se cerrará el acceso a votación permanently.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.orange)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _changeStatus(EstadoEleccion.FINALIZADA),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('FINALIZAR ELECCIÓN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.grey.shade400, size: 40),
          const SizedBox(height: 16),
          const Text('ELECCIÓN FINALIZADA', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 16, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Ya no se aceptan más votos para esta elección.', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
        final rawData = snapshot.data ?? [];

        // Deduplicar: cada socio debe aparecer una sola vez
        final Map<String, Map<String, dynamic>> uniqueUsers = {};
        for (var row in rawData) {
          final userId = row['usuario_id'] ?? row['nombre_usuario'];
          if (!uniqueUsers.containsKey(userId)) {
            uniqueUsers[userId] = Map<String, dynamic>.from(row);
          } else {
            // Si ya existe y el actual dice que ha votado, actualizamos (por seguridad)
            if (row['ha_votado'] == true) {
              uniqueUsers[userId]!['ha_votado'] = true;
              uniqueUsers[userId]!['fecha_voto'] = row['fecha_voto'];
            }
          }
        }

        final data = uniqueUsers.values.toList();
        int votaron = data.where((u) => u['ha_votado'] == true).length;
        int faltan = data.length - votaron;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCard('SOCIOS PARTICIPARON', votaron.toString(), Colors.green),
                  _statCard('SOCIOS PENDIENTES', faltan.toString(), Colors.orange),
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
                    subtitle: Text(u['ha_votado'] 
                      ? 'Participó el ${u['fecha_voto'].toString().split('T')[0]}' 
                      : 'Aún no ha participado'),
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
