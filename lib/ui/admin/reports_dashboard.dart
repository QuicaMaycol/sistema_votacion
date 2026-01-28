import 'package:flutter/material.dart';
import '../../services/election_service.dart';
import '../../models/eleccion_pregunta.dart';

class ReportsDashboard extends StatefulWidget {
  final String empresaId;

  const ReportsDashboard({super.key, required this.empresaId});

  @override
  State<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<ReportsDashboard> with SingleTickerProviderStateMixin {
  final _electionService = ElectionService();
  
  List<Eleccion> _elecciones = [];
  String? _selectedEleccionId;
  bool _isLoading = true;
  TabController? _tabController;

  // Data
  List<Map<String, dynamic>> _avance = [];
  List<Map<String, dynamic>> _resultados = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadElections();
  }

  Future<void> _loadElections() async {
    setState(() => _isLoading = true);
    try {
      final data = await _electionService.getElections(widget.empresaId);
      setState(() {
        _elecciones = data;
        if (data.isNotEmpty) {
          _selectedEleccionId = data.first.id;
          _loadReports(_selectedEleccionId!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      debugPrint('Error loading elections: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReports(String eleccionId) async {
    setState(() => _isLoading = true);
    try {
      final avanceData = await _electionService.getParticipationReport(eleccionId);
      final resultadosData = await _electionService.getResultsReport(eleccionId);
      
      setState(() {
        _avance = avanceData;
        _resultados = resultadosData;
      });
    } catch (e) {
      debugPrint('Error loading reports: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      appBar: AppBar(
        title: const Text('Reportes y Resultados', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: 'Avance de Participación'),
            Tab(text: 'Resultados de Votación'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selector de Elección
          if (_elecciones.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: DropdownButtonFormField<String>(
                value: _selectedEleccionId,
                decoration: const InputDecoration(
                  labelText: 'Seleccionar Elección',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                items: _elecciones.map((e) => DropdownMenuItem(
                  value: e.id,
                  child: Text(e.titulo, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedEleccionId = val);
                    _loadReports(val);
                  }
                },
              ),
            ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvanceTab(),
                    _buildResultadosTab(),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: AVANCE ---
  Widget _buildAvanceTab() {
    if (_avance.isEmpty) return const Center(child: Text('No hay datos de participación.'));

    final totalSocios = _avance.length;
    final completados = _avance.where((s) => s['estado'] == 'COMPLETADO').length;
    final pendientes = totalSocios - completados;
    final porcentaje = totalSocios > 0 ? (completados / totalSocios) : 0.0;

    return Column(
      children: [
        // Resumen
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)],
          ),
          child: Row(
            children: [
              CircularProgressIndicator(
                value: porcentaje,
                backgroundColor: Colors.grey.shade200,
                color: Colors.green,
                strokeWidth: 8,
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${(porcentaje * 100).toStringAsFixed(1)}% Completado', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('$completados votaron / $pendientes faltan', style: TextStyle(color: Colors.grey.shade600)),
                ],
              )
            ],
          ),
        ),

        // Lista Detallada
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _avance.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final socio = _avance[index];
              final estado = socio['estado'];
              final isDone = estado == 'COMPLETADO';
              final isPartial = estado == 'PARCIAL';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDone ? Colors.green.shade50 : (isPartial ? Colors.orange.shade50 : Colors.grey.shade100),
                    child: Icon(
                      isDone ? Icons.check : (isPartial ? Icons.timelapse : Icons.hourglass_empty),
                      color: isDone ? Colors.green : (isPartial ? Colors.orange : Colors.grey),
                    ),
                  ),
                  title: Text(socio['nombre'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('DNI: ${socio['dni']}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDone ? Colors.green : (isPartial ? Colors.orange : Colors.grey),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 2: RESULTADOS ---
  Widget _buildResultadosTab() {
    if (_resultados.isEmpty) return const Center(child: Text('No hay resultados registrados aún.'));

    // Agrupar por pregunta
    final preguntas = <String, List<Map<String, dynamic>>>{};
    for (var r in _resultados) {
      final key = r['texto_pregunta'] as String;
      if (!preguntas.containsKey(key)) preguntas[key] = [];
      preguntas[key]!.add(r);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: preguntas.entries.map((entry) {
        final titulo = entry.key;
        final opciones = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
                ...opciones.map((o) {
                  final label = o['texto_opcion'] ?? 'Valor: ${o['valor_numerico']}';
                  final count = o['conteo'];
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(label)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text('$count votos', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
