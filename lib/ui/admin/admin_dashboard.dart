import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../models/eleccion_pregunta.dart';
import '../../models/enums.dart';
import '../../services/auth_service.dart';
import 'create_election_screen.dart';
import 'election_control_screen.dart';
import 'admin_home_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();
  final _electionService = ElectionService();
  
  late RealtimeChannel _presenceChannel;
  int _onlineUsers = 0;

  @override
  void initState() {
    super.initState();
    _initPresence();
  }

  void _initPresence() {
    final client = Supabase.instance.client;
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile == null) return;

    _presenceChannel = client.channel('quorum:${profile.empresaId}');
    
    _presenceChannel.onPresenceSync((payload) {
      final states = _presenceChannel.presenceState();
      setState(() {
        _onlineUsers = states.length;
      });
    }).onPresenceJoin((payload) {
      debugPrint('Usuario se unió: ${payload.newPresences}');
    }).onPresenceLeave((payload) {
      debugPrint('Usuario salió: ${payload.leftPresences}');
    }).subscribe((status, [error]) async {
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

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().currentProfile;

    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Admin: ${profile.nombre}',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout_rounded, color: Colors.blueGrey),
              tooltip: 'Cerrar Sesión',
            )
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: Colors.blue.shade700,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_rounded), text: 'Inicio'),
              Tab(icon: Icon(Icons.how_to_vote), text: 'Elecciones'),
              Tab(icon: Icon(Icons.person_add_alt), text: 'Solicitudes'),
              Tab(icon: Icon(Icons.people), text: 'Socios Activos'),
              Tab(icon: Icon(Icons.badge_rounded), text: 'Equipo'),
            ],
          ),
        ),
        body: Container(
          color: Colors.white,
          child: TabBarView(
            children: [
              AdminHomeTab(empresaId: profile.empresaId, onlineUsers: _onlineUsers),
              _buildElectionsTab(profile.empresaId),
              _buildRequestsTab(profile.empresaId),
              _buildSociosTab(profile.empresaId),
              _buildTeamTab(profile.empresaId),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateElectionScreen()),
            ).then((_) => setState(() {}));
          },
          icon: const Icon(Icons.add),
          label: const Text('Nueva Elección'),
        ),
      ),
    );
  }

  Widget _buildElectionsTab(String empresaId) {
    return FutureBuilder<List<Eleccion>>(
      future: _electionService.getElections(empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final elections = snapshot.data ?? [];
        if (elections.isEmpty) return const Center(child: Text('No hay elecciones creadas.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: elections.length,
          itemBuilder: (context, index) {
            final e = elections[index];
            final color = e.estado == EstadoEleccion.FINALIZADA ? Colors.grey : Colors.blue;
            return Card(
              child: ListTile(
                leading: Icon(Icons.event, color: color),
                title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Estado: ${e.estado.name.toUpperCase()}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ElectionControlScreen(eleccion: e),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab(String empresaId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _authService.getPendingUsers(empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        
        final users = snapshot.data ?? [];
        if (users.isEmpty) return const Center(child: Text('No hay solicitudes pendientes.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            return Card(
              child: ListTile(
                title: Text(u['nombre']),
                subtitle: Text('DNI: ${u['dni']} | ${u['created_at'].toString().split('T')[0]}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _handleApproval(u['id'], EstadoUsuario.ACTIVO),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _handleApproval(u['id'], EstadoUsuario.BLOQUEADO),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSociosTab(String empresaId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _authService.getSocioList(empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        
        final socios = snapshot.data ?? [];
        if (socios.isEmpty) return const Center(child: Text('No hay socios registrados.'));

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('DNI')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acción')),
            ],
            rows: socios.map((s) => DataRow(cells: [
              DataCell(Text(s['nombre'])),
              DataCell(Text(s['dni'])),
              DataCell(Chip(label: Text(s['estado_acceso']), 
                       backgroundColor: s['estado_acceso'] == 'ACTIVO' ? Colors.green.shade100 : Colors.red.shade100)),
              DataCell(
                s['estado_acceso'] == 'ACTIVO' 
                ? IconButton(icon: const Icon(Icons.block, color: Colors.red), onPressed: () => _handleApproval(s['id'], EstadoUsuario.BLOQUEADO))
                : IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _handleApproval(s['id'], EstadoUsuario.ACTIVO))
              ),
            ])).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTeamTab(String empresaId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Miembros de Gestión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showCreateStaffDialog(empresaId),
                icon: const Icon(Icons.add),
                label: const Text('Añadir Miembro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _authService.getStaffList(empresaId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final staff = snapshot.data ?? [];
              if (staff.isEmpty) return const Center(child: Text('No hay miembros registrados.'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  final s = staff[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: s['rol'] == 'ADMIN' ? Colors.indigo.shade100 : Colors.orange.shade100,
                        child: Icon(
                          s['rol'] == 'ADMIN' ? Icons.security : Icons.visibility,
                          color: s['rol'] == 'ADMIN' ? Colors.indigo : Colors.orange,
                        ),
                      ),
                      title: Text(s['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('DNI: ${s['dni']} | Rol: ${s['rol']}'),
                      trailing: const Icon(Icons.more_vert),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateStaffDialog(String empresaId) {
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final nameController = TextEditingController();
    final dniController = TextEditingController();
    RolUsuario selectedRol = RolUsuario.GERENCIA;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear Miembro de Gestión'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre Completo')),
                TextField(controller: dniController, decoration: const InputDecoration(labelText: 'DNI / Identificación')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Correo Electrónico'), keyboardType: TextInputType.emailAddress),
                TextField(controller: passController, decoration: const InputDecoration(labelText: 'Contraseña Temporal'), obscureText: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<RolUsuario>(
                  value: selectedRol,
                  decoration: const InputDecoration(labelText: 'Rol en el Sistema'),
                  items: [RolUsuario.ADMIN, RolUsuario.GERENCIA].map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r == RolUsuario.ADMIN ? 'Administrador (Todo)' : 'Gerencia (Solo Lectura)'),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedRol = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _authService.createStaffUser(
                    email: emailController.text.trim(),
                    password: passController.text.trim(),
                    nombre: nameController.text.trim(),
                    dni: dniController.text.trim(),
                    rol: selectedRol,
                  );
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado exitosamente')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Crear Usuario'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApproval(String userId, EstadoUsuario nuevoEstado) async {
    try {
      await _authService.updateEstadoAcceso(userId, nuevoEstado);
      setState(() {}); // Refresh UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario ${nuevoEstado == EstadoUsuario.ACTIVO ? 'Aprobado' : 'Rechazado'}'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

extension on List {
  int get size => length;
}
