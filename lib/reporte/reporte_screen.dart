import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'reporte_service.dart';
import '../services/election_service.dart';
import '../models/eleccion_pregunta.dart';
import '../models/enums.dart';
import '../providers/auth_provider.dart';

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({super.key});

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> with SingleTickerProviderStateMixin {
  final _reporteService = ReporteService();
  final _electionService = ElectionService();
  
  late TabController _tabController;
  
  List<Eleccion> _elecciones = [];
  String? _selectedEleccionId;
  bool _isLoading = true;

  // Datos de participación
  List<Map<String, dynamic>> _participacion = [];
  List<Map<String, dynamic>> _filteredParticipacion = [];
  String _filterStatus = 'TODOS'; // TODOS, VOTARON, PENDIENTES
  String _searchQuery = '';

  // Datos de resultados
  Map<String, List<Map<String, dynamic>>> _resultadosPorSede = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile == null) return;

    setState(() => _isLoading = true);
    try {
      final elections = await _electionService.getElections(profile.empresaId);
      setState(() {
        _elecciones = elections;
        if (elections.isNotEmpty) {
          _selectedEleccionId = elections.first.id;
        }
      });
      if (_selectedEleccionId != null) {
        await _loadReportData();
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReportData() async {
    if (_selectedEleccionId == null) return;
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile == null) return;

    setState(() => _isLoading = true);
    try {
      final partData = await _reporteService.getParticipacionDetallada(profile.empresaId, _selectedEleccionId!);
      final resData = await _reporteService.getResultadosPorSede(_selectedEleccionId!);

      setState(() {
        _participacion = partData;
        _resultadosPorSede = resData;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading report data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredParticipacion = _participacion.where((s) {
        final matchesSearch = s['nombre'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                             s['dni'].toString().contains(_searchQuery);
        
        bool matchesStatus = true;
        if (_filterStatus == 'VOTARON') {
          matchesStatus = s['ha_votado'] == true;
        } else if (_filterStatus == 'PENDIENTES') {
          matchesStatus = s['ha_votado'] == false;
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Centro de Reportes Avanzado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: 'Participación Detallada'),
            Tab(text: 'Ganadores por Sede'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildElectionSelector(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildParticipacionTab(),
                    _buildResultadosTab(),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectionSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.how_to_vote, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedEleccionId,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Elección Seleccionada',
                border: OutlineInputBorder(),
              ),
              items: _elecciones.map((e) => DropdownMenuItem(
                value: e.id,
                child: Text(e.titulo, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedEleccionId = val);
                  _loadReportData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipacionTab() {
    return Column(
      children: [
        _buildFiltersSection(),
        _buildSummaryStats(),
        Expanded(child: _buildSociosList()),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o DNI...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _filterChip('TODOS', 'Todos'),
              const SizedBox(width: 8),
              _filterChip('VOTARON', 'Ya Votaron'),
              const SizedBox(width: 8),
              _filterChip('PENDIENTES', 'Faltan Votar'),
            ],
          )
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    final isSelected = _filterStatus == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = id);
          _applyFilters();
        }
      },
      selectedColor: Colors.blueAccent.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blueAccent : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      ),
    );
  }

  Widget _buildSummaryStats() {
    final total = _participacion.length;
    final votaron = _participacion.where((s) => s['ha_votado']).length;
    final pendientes = total - votaron;
    final porcentaje = total > 0 ? (votaron / total) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _statCard('Total Socios', total.toString(), Colors.blue),
          const SizedBox(width: 12),
          _statCard('Votaron', votaron.toString(), Colors.green),
          const SizedBox(width: 12),
          _statCard('Pendientes', pendientes.toString(), Colors.orange),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 12, color: color.withAlpha(150))),
          ],
        ),
      ),
    );
  }

  Widget _buildSociosList() {
    if (_filteredParticipacion.isEmpty) {
      return const Center(child: Text('No se encontraron registros con los filtros actuales.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredParticipacion.length,
      itemBuilder: (context, index) {
        final socio = _filteredParticipacion[index];
        final bool isDone = socio['ha_votado'] == true;
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDone ? Colors.green.shade50 : Colors.orange.shade50,
              child: Icon(
                isDone ? Icons.check_circle : Icons.pending,
                color: isDone ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(socio['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('DNI: ${socio['dni']}'),
            trailing: Text(
              isDone ? 'VOTÓ' : 'PENDIENTE',
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.bold,
                color: isDone ? Colors.green : Colors.orange
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultadosTab() {
    if (_resultadosPorSede.isEmpty) {
      return const Center(child: Text('No hay resultados de candidatos registrados.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _resultadosPorSede.entries.map((entry) {
        final sede = entry.key;
        final candidatos = entry.value;
        final ganador = candidatos.isNotEmpty ? candidatos.first : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sede.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Icon(Icons.location_on, color: Colors.white70, size: 16),
                  ],
                ),
              ),
              ...candidatos.map((c) {
                final isWinner = ganador != null && c['id'] == ganador['id'] && c['votos'] > 0;
                return ListTile(
                  leading: Text('#${c['numero']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  title: Text(c['nombre']),
                  subtitle: isWinner 
                    ? Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text('LIDERANDO', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      )
                    : null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isWinner ? Colors.green : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${c['votos']} votos', 
                      style: TextStyle(
                        color: isWinner ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }
}
