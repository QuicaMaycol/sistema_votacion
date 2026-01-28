import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import 'voting_card.dart';

class SocioDashboard extends StatefulWidget {
  const SocioDashboard({super.key});

  @override
  State<SocioDashboard> createState() => _SocioDashboardState();
}

class _SocioDashboardState extends State<SocioDashboard> {
  final _electionService = ElectionService();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>(); 
  List<Map<String, dynamic>> _preguntas = [];
  bool _isLoading = true;
  bool _isConnected = false;
  String _debugStatus = 'Iniciando...';
  String _clientLog = '';
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    // Primera ejecución inmediata
    _sendHeartbeat();
    // Repetir cada 15 segundos
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sendHeartbeat());
  }

  Future<void> _sendHeartbeat() async {
    final client = Supabase.instance.client;
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile == null) return;

    try {
      await client.rpc('registrar_heartbeat', params: {
        'p_user_id': profile.id,
        'p_metadata': {'nombre': profile.nombre, 'empresa_id': profile.empresaId}
      });
      
      if (mounted) {
         setState(() {
           _isConnected = true;
           _debugStatus = 'Heartbeat OK: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}';
         });
      }
    } catch (e) {
      debugPrint('Heartbeat Error: $e');
      if (mounted) {
        setState(() {
           _isConnected = false;
           _debugStatus = 'Error: $e';
           _clientLog = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = context.read<AuthProvider>().currentProfile;
      if (profile == null) {
        // Si por alguna razón no hay perfil, no podemos cargar datos
        setState(() => _preguntas = []);
        return;
      }
      final data = await _electionService.getPendingQuestionsForSocio(profile.id);
      setState(() => _preguntas = data);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onVoted(int index) {
    final removedItem = _preguntas[index];
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: VotingCard(preguntaData: removedItem, onVoted: () {}),
      ),
      duration: const Duration(milliseconds: 500),
    );

    setState(() {
      _preguntas.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Voto registrado con éxito! 🗳️'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().currentProfile;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text('Hola, ${profile?.nombre ?? 'Socio'}'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.how_to_vote), text: 'VOTAR'),
              Tab(icon: Icon(Icons.history), text: 'MIS VOTOS'),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(_isConnected ? Icons.wifi : Icons.wifi_off, size: 16, color: _isConnected ? Colors.green.shade800 : Colors.red.shade800),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? 'Conectado' : 'Desconectado', 
                    style: TextStyle(color: _isConnected ? Colors.green.shade800 : Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout),
            )
          ],
        ),
        body: TabBarView(
          children: [
            _buildVotingList(),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVotingList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_preguntas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade200),
            const SizedBox(height: 16),
            const Text(
              '¡Estás al día!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('No tienes elecciones pendientes en este momento.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('Actualizar')),
          ],
        ),
      );
    }

    return AnimatedList(
      key: _listKey,
      padding: const EdgeInsets.all(16),
      initialItemCount: _preguntas.length,
      itemBuilder: (context, index, animation) {
        return FadeTransition(
          opacity: animation,
          child: VotingCard(
            key: ValueKey(_preguntas[index]['id']),
            preguntaData: _preguntas[index],
            onVoted: () => _onVoted(index),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile == null) return const Center(child: Text('No identificado'));

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _electionService.getMyVoteHistory(profile.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];

        if (data.isEmpty) return const Center(child: Text('Aún no has emitido ningún voto.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final v = data[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.done_all, color: Colors.green),
                title: Text(v['preguntas']?['texto_pregunta'] ?? 'Pregunta no disponible'),
                subtitle: Text(
                  v['opciones'] != null 
                    ? 'Opción: ${v['opciones']['texto_opcion']}' 
                    : (v['valor_numerico'] != null ? 'Valor: ${v['valor_numerico']}' : 'Sin respuesta')
                ),
                trailing: Text(
                  _formatTimestamp(v['timestamp']), 
                  style: const TextStyle(fontSize: 10, color: Colors.grey)
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return ts.toString().split('T')[0];
    }
  }
}
