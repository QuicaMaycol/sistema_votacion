import 'package:flutter/material.dart';
import '../../models/eleccion_pregunta.dart';
import '../../models/enums.dart';
import '../../services/election_service.dart';
import 'result_chart.dart';
import 'election_control_screen.dart';

class AdminHomeTab extends StatefulWidget {
  final String empresaId;
  final int onlineUsers;

  const AdminHomeTab({
    super.key,
    required this.empresaId,
    required this.onlineUsers,
  });

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  final _electionService = ElectionService();
  bool _isLoading = true;
  Eleccion? _activeElection;
  List<PreguntaCompleta> _preguntas = [];
  List<Map<String, dynamic>> _resultados = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final elections = await _electionService.getElections(widget.empresaId);
      // Buscar la primera elección activa
      _activeElection = elections.firstWhere(
        (e) => e.estado == EstadoEleccion.ACTIVA,
        orElse: () => elections.firstWhere((e) => e.estado == EstadoEleccion.BORRADOR, orElse: () => elections.first),
      );

      if (_activeElection != null) {
        _preguntas = await _electionService.getQuestionsByElection(_activeElection!.id);
        _resultados = await _electionService.getResultsByElection(_activeElection!.id);
      }
    } catch (e) {
      debugPrint('Error en Dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSteveHeader(),
            const SizedBox(height: 24),
            _buildQuorumCard(),
            const SizedBox(height: 24),
            if (_activeElection != null) ...[
              _buildActiveElectionCard(),
              const SizedBox(height: 24),
              _buildLeaderboardCard(),
            ] else
              _buildEmptyState(),
            const SizedBox(height: 32),
            _buildQuickActions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSteveHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Panel de Control',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueAccent, letterSpacing: 1.2),
        ),
        SizedBox(height: 4),
        Text(
          'Estado General',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1),
        ),
      ],
    );
  }

  Widget _buildQuorumCard() {
    return InkWell(
      onTap: () {
        DefaultTabController.of(context).animateTo(3);
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                ),
                const _PulseCircle(),
                const Icon(Icons.people_alt_rounded, color: Colors.green, size: 30),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.onlineUsers.toString(),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                  const Text(
                    'Socios en línea ahora',
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveElectionCard() {
    final e = _activeElection!;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ElectionControlScreen(eleccion: e),
          ),
        ).then((_) => _loadDashboardData());
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ELECCIÓN ACTIVA', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              e.titulo,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              e.descripcion ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Finaliza: ${e.fechaFin.toString().split(' ')[0]}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard() {
    if (_resultados.isEmpty) return const SizedBox.shrink();

    // Obtener la pregunta con más votos
    final pc = _preguntas.first;
    final resDePregunta = _resultados.where((r) => r['pregunta_id'] == pc.pregunta.id).toList();
    
    // Encontrar el ganador (el que tiene más total_votos)
    Map<String, dynamic>? ganador;
    if (resDePregunta.isNotEmpty) {
      resDePregunta.sort((a, b) => (b['total_votos'] as int).compareTo(a['total_votos'] as int));
      ganador = resDePregunta.first;
    }

    String textoGanador = "Calculando...";
    if (ganador != null) {
      if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE) {
        final opt = pc.opciones.firstWhere((o) => o.id == ganador!['opcion_elegida_id'], orElse: () => null as dynamic);
        textoGanador = opt?.textoOpcion ?? "Sin votos";
      } else {
        textoGanador = "Valor: ${ganador['valor_numerico']}";
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TENDENCIA ACTUAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pc.pregunta.textoPregunta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Liderando:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                      textoGanador,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${ganador?['total_votos'] ?? 0} Votos',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _getWinnerPercentage(ganador),
              backgroundColor: Colors.grey.shade100,
              color: Colors.blue.shade400,
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  double _getWinnerPercentage(Map<String, dynamic>? ganador) {
    if (ganador == null || _resultados.isEmpty) return 0.0;
    int total = _resultados
        .where((r) => r['pregunta_id'] == ganador['pregunta_id'])
        .fold(0, (sum, item) => sum + (item['total_votos'] as int));
    if (total == 0) return 0.0;
    return (ganador['total_votos'] as int) / total;
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: Text('No hay elecciones activas en este momento.', textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _actionItem(Icons.analytics_rounded, 'Reportes', () {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Generando reporte detallado de participación...'))
           );
        }),
        const SizedBox(width: 16),
        _actionItem(Icons.history_edu_rounded, 'Histórico', () {}),
        const SizedBox(width: 16),
        _actionItem(Icons.rocket_launch_rounded, 'Nueva', () {}),
      ],
    );
  }

  Widget _actionItem(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.blueGrey),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseCircle extends StatefulWidget {
  const _PulseCircle();

  @override
  State<_PulseCircle> createState() => _PulseCircleState();
}

class _PulseCircleState extends State<_PulseCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 50 + (10 * _controller.value),
          height: 50 + (10 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.withOpacity(1 - _controller.value), width: 2),
          ),
        );
      },
    );
  }
}
