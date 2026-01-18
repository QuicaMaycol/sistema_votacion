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
  late RealtimeChannel _presenceChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initPresence();
  }

  void _initPresence() {
    final client = Supabase.instance.client;
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile == null) return;

    _presenceChannel = client.channel('quorum:${profile.empresaId}');
    _presenceChannel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel.track({
          'user_id': profile.id,
          'nombre': profile.nombre,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  @override
  void dispose() {
    _presenceChannel.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _electionService.getPendingQuestionsForSocio();
      setState(() => _preguntas = data);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onVoted(int index) {
    // 1. Mostrar Confeti o Feedback visual si se desea (opcional)
    
    // 2. Animar desaparición
    final removedItem = _preguntas[index];
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: VotingCard(preguntaData: removedItem, onVoted: () {}),
      ),
      duration: const Duration(milliseconds: 500),
    );

    // 3. Remover de la lista real
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _electionService.getMyVoteHistory(),
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
                title: Text(v['preguntas']['texto_pregunta']),
                subtitle: Text(
                  v['opciones'] != null 
                    ? 'Opción: ${v['opciones']['texto_opcion']}' 
                    : 'Valor: ${v['valor_numerico']}'
                ),
                trailing: Text(
                  v['timestamp'].toString().split(' ')[0], 
                  style: const TextStyle(fontSize: 10, color: Colors.grey)
                ),
              ),
            );
          },
        );
      },
    );
  }
}
