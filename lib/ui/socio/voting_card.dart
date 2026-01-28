import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../services/election_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
  final _searchController = TextEditingController();
  
  bool _isVoting = false;
  List<Opcion> _opciones = [];
  List<Opcion> _filteredOciones = [];
  bool _isLoadingOpciones = false;
  Opcion? _selectedCandidate; 

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
    _searchController.addListener(_filterCandidates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _checkAndLoad() {
    final tipo = widget.preguntaData['tipo']?.toString().toUpperCase() ?? '';
    if (tipo == 'OPCION_MULTIPLE' || tipo == 'SI_NO' || tipo == 'BOLEANO' || tipo == 'CANDIDATOS') {
      _loadOpciones();
    }
  }

  void _filterCandidates() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOciones = _opciones;
      } else {
        _filteredOciones = _opciones.where((o) => o.textoOpcion.toLowerCase().contains(query)).toList();
      }
    });
  }

  Future<void> _loadOpciones() async {
    setState(() => _isLoadingOpciones = true);
    try {
      final eleccionId = widget.preguntaData['eleccion_id'] ?? widget.preguntaData['eleccionId'];
      final preguntaId = widget.preguntaData['id'];

      if (eleccionId == null || preguntaId == null) {
        throw 'Faltan IDs necesarios para cargar opciones';
      }

      final pc = await _electionService.getQuestionsByElection(eleccionId);
      final estaPregunta = pc.where((p) => p.pregunta.id == preguntaId).firstOrNull;
      
      if (estaPregunta != null && estaPregunta.opciones.isNotEmpty) {
        setState(() {
          _opciones = estaPregunta.opciones;
          _filteredOciones = _opciones;
        });
      } else {
        _tryFallbackOpciones();
      }
    } catch (e) {
      debugPrint('Error cargando opciones: $e');
      _tryFallbackOpciones();
    } finally {
      setState(() => _isLoadingOpciones = false);
    }
  }

  void _tryFallbackOpciones() {
    final tipo = widget.preguntaData['tipo']?.toString().toUpperCase() ?? '';
    
    // NO generar fallback para CANDIDATOS, queremos ver si la lista está vacía real.
    if (tipo == 'CANDIDATOS') {
       setState(() {
         _opciones = []; 
         _filteredOciones = [];
       });
       return;
    }

    if (_opciones.isEmpty) {
      setState(() {
        _opciones = [
          Opcion(id: 'AUTO_SI', preguntaId: widget.preguntaData['id'], textoOpcion: 'Sí'),
          Opcion(id: 'AUTO_NO', preguntaId: widget.preguntaData['id'], textoOpcion: 'No'),
        ];
        _filteredOciones = _opciones;
      });
    }
  }

  Future<void> _votar(String? opcionId, double? valor) async {
    if (_isVoting) return;

    setState(() => _isVoting = true);
    try {
      // OBTENER ID DEL USUARIO DESDE EL PROVIDER
      // Ya que el login por DNI no crea sesión de Supabase Auth, el currentUser es null.
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentProfile?.id;

      if (userId == null) {
        throw 'No se pudo identificar al usuario votante. Intente recargar.';
      }

      await _electionService.votar(
        usuarioId: userId,
        preguntaId: widget.preguntaData['id'],
        opcionId: (opcionId?.startsWith('AUTO_') ?? false) ? null : opcionId,
        valorNumerico: (opcionId == 'AUTO_SI') ? 1.0 : (opcionId == 'AUTO_NO' ? 0.0 : valor),
      );
      widget.onVoted(); 
    } catch (e) {
      debugPrint('Error al votar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.preguntaData['tipo']?.toString().toUpperCase() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7), // Más sólido
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Text(
                widget.preguntaData['texto_pregunta'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.black87),
              ),
              const SizedBox(height: 32),
              if (_isVoting)
                const Center(child: CircularProgressIndicator(color: Colors.black))
              else if (tipo == 'CANDIDATOS')
                _buildCandidatesList()
              else if (tipo == 'OPCION_MULTIPLE' || tipo == 'SI_NO')
                _buildMultipleChoice()
              else
                _buildNumericInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(
            widget.preguntaData['titulo_eleccion']?.toString().toUpperCase() ?? 'ELECCIÓN',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesList() {
    if (_isLoadingOpciones) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Buscador
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar candidato...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            itemCount: _filteredOciones.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final op = _filteredOciones[index];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black87,
                  child: Text((op.valor != null && op.valor!.isNotEmpty) ? op.valor! : '#'),
                ),
                title: Text(op.textoOpcion, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  ),
                  onPressed: () => _showConfirmationDialog(op),
                  child: const Text('VOTAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
        if (_filteredOciones.isEmpty)
           const Padding(
             padding: EdgeInsets.all(16.0),
             child: Text('No se encontraron candidatos', style: TextStyle(color: Colors.grey)),
           )
      ],
    );
  }

  Future<void> _showConfirmationDialog(Opcion op) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Voto'),
        content: Text('¿Desea votar por ${op.textoOpcion}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Confirmar Voto')
          ),
        ],
      ),
    );

    if (confirmar == true) {
      _votar(op.id, null);
    }
  }

  Widget _buildMultipleChoice() {
    if (_isLoadingOpciones) return const Center(child: CircularProgressIndicator());

    return Column(
      children: _opciones.map((o) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            minimumSize: const Size(double.infinity, 60),
            elevation: 0,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            splashFactory: InkRipple.splashFactory,
          ),
          onPressed: () => _votar(o.id, null),
          child: Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400, width: 2)
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(o.textoOpcion, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildNumericInput() {
    return Column(
      children: [
        TextField(
          controller: _numController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: Colors.black.withOpacity(0.3),
          ),
          onPressed: () {
            final val = double.tryParse(_numController.text);
            if (val != null) _votar(null, val);
          },
          child: const Text('ENVIAR VOTO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
        ),
      ],
    );
  }
}
