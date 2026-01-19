import 'package:flutter/material.dart';
import '../../models/eleccion_pregunta.dart';
import '../../models/enums.dart';
import '../../services/election_service.dart';
import 'result_chart.dart';
import 'election_control_screen.dart';

class AdminHomeTab extends StatefulWidget {
  final String empresaId;
  final int onlineUsers;
  final VoidCallback? onVisitSocios;

  const AdminHomeTab({
    super.key,
    required this.empresaId,
    required this.onlineUsers,
    this.onVisitSocios,
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

    final isMobile = MediaQuery.of(context).size.width < 900;
    final padding = isMobile ? 24.0 : 48.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSteveHeader(),
                      const SizedBox(height: 32),
                      
                      // Responsive Top Section
                      if (!isMobile)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildQuorumCard()),
                            const SizedBox(width: 24),
                            if (_activeElection != null)
                              Expanded(child: _buildActiveElectionCard())
                            else
                              Expanded(child: _buildEmptyState()),
                          ],
                        )
                      else ...[
                        _buildQuorumCard(),
                        const SizedBox(height: 24),
                        if (_activeElection != null)
                          _buildActiveElectionCard()
                        else
                          _buildEmptyState(),
                      ],
                      
                      const SizedBox(height: 24),
                      if (_activeElection != null)
                        _buildLeaderboardCard(),
                        
                      const SizedBox(height: 48),
                      const Text(
                        'Acciones rápidas',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.7),
                      ),
                      const SizedBox(height: 20),
                      _buildQuickActions(isMobile),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteveHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateTime.now().toString().split(' ')[0], // Simular fecha dinámica
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        const Text(
          'Dashboard',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildQuorumCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _PulseCircle(color: Colors.green.shade400),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.onlineUsers.toString(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -1),
                ),
                Text(
                  'SOCIOS CONECTADOS',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: widget.onVisitSocios,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Ver lista', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveElectionCard() {
    final e = _activeElection!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black, // Dark mode for active item
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('EN VIVO', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const Icon(Icons.more_horiz, color: Colors.white54),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            e.titulo,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            e.descripcion ?? 'Sin descripción disponible para esta elección.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ElectionControlScreen(eleccion: e),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Gestionar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard() {
    if (_resultados.isEmpty) return const SizedBox.shrink();

    final pc = _preguntas.first;
    final resDePregunta = _resultados.where((r) => r['pregunta_id'] == pc.pregunta.id).toList();
    
    Map<String, dynamic>? ganador;
    if (resDePregunta.isNotEmpty) {
      resDePregunta.sort((a, b) => (b['total_votos'] as int).compareTo(a['total_votos'] as int));
      ganador = resDePregunta.first;
    }

    String textoGanador = "Sin datos";
    if (ganador != null) {
      if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE) {
        final opt = pc.opciones.firstWhere((o) => o.id == ganador!['opcion_elegida_id'], orElse: () => null as dynamic);
        textoGanador = opt?.textoOpcion ?? "Anónimo";
      } else {
        textoGanador = "Valor: ${ganador['valor_numerico']}";
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text('RESULTADOS PARCIALES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            pc.pregunta.textoPregunta,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.2),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Liderando', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text(
                      textoGanador,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${ganador?['total_votos'] ?? 0} votos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${(_getWinnerPercentage(ganador) * 100).toInt()}% del total', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _getWinnerPercentage(ganador),
              backgroundColor: Colors.grey.shade100,
              color: Colors.blueAccent,
              minHeight: 8,
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No hay elecciones activas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea una nueva elección para comenzar a recibir votos en tiempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.5 : 1.3,
      children: [
        _actionItem(Icons.auto_graph_rounded, 'Reportes', Colors.blue, () {}),
        _actionItem(Icons.history_rounded, 'Historial', Colors.orange, () {}),
        _actionItem(Icons.people_outline_rounded, 'Usuarios', Colors.purple, () {}),
        _actionItem(Icons.settings_outlined, 'Ajustes', Colors.blueGrey, () {}),
      ],
    );
  }

  Widget _actionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

class _PulseCircle extends StatefulWidget {
  final Color color;
  const _PulseCircle({required this.color});

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
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 20 + (30 * _controller.value),
              height: 20 + (30 * _controller.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(1 - _controller.value),
              ),
            );
          },
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}
