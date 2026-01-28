import 'dart:async';
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
import 'admin_padron_screen.dart';
import 'reports_dashboard.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();
  final _electionService = ElectionService();
  
  Timer? _presenceTimer;

  int _onlineUsers = 0;
  Set<String> _onlineUserIds = {};
  int _selectedIndex = 0;
  String? _empresaNombre;

  @override
  void initState() {
    super.initState();
    _startPresencePolling();
    _loadEmpresaInfo();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }
  
  void _loadEmpresaInfo() async {
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile != null) {
      final name = await _authService.getEmpresaName(profile.empresaId);
      if (mounted) setState(() => _empresaNombre = name);
    }
  }

  void _startPresencePolling() {
    _fetchOnlineUsers();
    _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchOnlineUsers());
  }

  Future<void> _fetchOnlineUsers() async {
    final profile = context.read<AuthProvider>().currentProfile;
    if (profile == null) return;

    try {
      // Buscamos heartbeats de los últimos 90 segundos (margen amplio)
      final limitTime = DateTime.now().subtract(const Duration(seconds: 90)).toIso8601String();
      
      final data = await Supabase.instance.client
          .from('presence_heartbeat')
          .select('user_id')
          .gt('last_seen', limitTime);
      
      final ids = <String>{};
      for (var row in data) {
        ids.add(row['user_id'] as String);
      }

      if (mounted) {
        setState(() {
          _onlineUsers = ids.length;
          _onlineUserIds = ids;
        });
      }
    } catch (e) {
      debugPrint('Error polling presence: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().currentProfile;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> pages = [
      AdminHomeTab(
        empresaId: profile.empresaId, 
        onlineUsers: _onlineUsers,
        onVisitSocios: () => setState(() => _selectedIndex = 3),
      ),
      _buildElectionsTab(profile.empresaId),
      _buildRequestsTab(profile.empresaId),
      _buildSociosTab(profile.empresaId),
      _buildTeamTab(profile.empresaId),
      ReportsDashboard(empresaId: profile.empresaId),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD), 
      appBar: AppBar(
        titleSpacing: isMobile ? 24 : 0,
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        centerTitle: false,
        leading: !isMobile ? Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo_votacion.png', width: 28),
        ) : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_empresaNombre ?? 'SISTEMA DE VOTACIONES').toUpperCase(),
              style: const TextStyle(
                color: Colors.grey, 
                fontSize: 10, 
                fontWeight: FontWeight.w600, 
                letterSpacing: 1.5
              ),
            ),
            Text(
              profile.nombre,
              style: const TextStyle(
                color: Colors.black, 
                fontWeight: FontWeight.bold, 
                fontSize: 20,
                letterSpacing: -0.5
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout_rounded, color: Colors.black87, size: 20),
              tooltip: 'Cerrar Sesión',
            ),
          )
        ],
      ),
      body: Row(
        children: [
          if (!isMobile) 
            _buildDesktopSidebar(),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: isMobile ? Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey.shade400,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.how_to_vote_rounded), label: 'Votos'),
            BottomNavigationBarItem(icon: Icon(Icons.person_add_rounded), label: 'Solicitudes'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Socios'),
            BottomNavigationBarItem(icon: Icon(Icons.badge_rounded), label: 'Equipo'),
          ],
        ),
      ) : null,
      floatingActionButton: _selectedIndex == 1 ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateElectionScreen()),
          ).then((_) => setState(() {}));
        },
        backgroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva Elección', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          _sidebarItem(0, Icons.dashboard_rounded, 'Inicio'),
          _sidebarItem(1, Icons.how_to_vote_rounded, 'Elecciones'),
          _sidebarItem(2, Icons.person_add_rounded, 'Solicitudes'),
          _sidebarItem(3, Icons.people_alt_rounded, 'Socios Activos'),
          _sidebarItem(4, Icons.badge_rounded, 'Equipo de Gestión'),
          const Divider(),
          _sidebarItem(5, Icons.bar_chart_rounded, 'Reportes'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Text('Centro de Ayuda', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
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
        if (elections.isEmpty) return _buildEmptyStateInTab('No hay elecciones creadas.');

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: elections.length,
              itemBuilder: (context, index) {
                final e = elections[index];
                final isFinished = e.estado == EstadoEleccion.FINALIZADA;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFinished ? Colors.grey.shade50 : Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.event_note_rounded, color: isFinished ? Colors.grey : Colors.blueAccent),
                    ),
                    title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Estado: ${e.estado.name.toUpperCase()} • Creada: ${e.fechaInicio.toString().split(' ')[0]}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
            ),
          ),
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
        if (users.isEmpty) return _buildEmptyStateInTab('No hay solicitudes pendientes.');

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text(u['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('DNI: ${u['dni']} • ${u['created_at'].toString().split('T')[0]}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionIconButton(Icons.check_rounded, Colors.green, () => _handleApproval(u['id'], EstadoUsuario.ACTIVO)),
                        const SizedBox(width: 8),
                        _actionIconButton(Icons.close_rounded, Colors.red, () => _handleApproval(u['id'], EstadoUsuario.BLOQUEADO)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _actionIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmptyStateInTab(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSociosTab(String empresaId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _authService.getSocioList(empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        
        final socios = snapshot.data ?? [];
        if (socios.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEmptyStateInTab('No hay socios registrados.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => AdminPadronScreen(empresaId: empresaId))
                  ).then((_) => setState((){})),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Cargar Padrón Masivo'),
                )
              ],
            )
          );
        }

        return Column(
          children: [
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Padrón de Socios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => AdminPadronScreen(empresaId: empresaId))
                        ).then((_) => setState((){})),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Cargar / Actualizar Masivo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: socios.length,
                    itemBuilder: (context, index) {
                      final s = socios[index];
                      final bool isActive = s['estado_acceso'] == 'ACTIVO';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                child: Text(s['nombre'][0].toUpperCase(), style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                              ),
                              if (_onlineUserIds.contains(s['id']))
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.shade700,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(s['nombre'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Row(
                            children: [
                              Text('DNI: ${s['dni']} • ${s['estado_acceso']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                              if (_onlineUserIds.contains(s['id']))
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('EN LÍNEA', style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive)
                                _actionIconButton(Icons.block_rounded, Colors.red, () => _handleApproval(s['id'], EstadoUsuario.BLOQUEADO))
                              else
                                _actionIconButton(Icons.check_circle_outline_rounded, Colors.green, () => _handleApproval(s['id'], EstadoUsuario.ACTIVO)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeamTab(String empresaId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gestión de Equipo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateStaffDialog(empresaId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nuevo Miembro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _authService.getStaffList(empresaId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final staff = snapshot.data ?? [];
              if (staff.isEmpty) return _buildEmptyStateInTab('No hay miembros registrados.');

              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: staff.length,
                    itemBuilder: (context, index) {
                      final s = staff[index];
                      final bool isAdmin = s['rol'] == 'ADMIN';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isAdmin ? Colors.indigo.shade50 : Colors.amber.shade50,
                            child: Icon(
                              isAdmin ? Icons.shield_rounded : Icons.person_search_rounded,
                              color: isAdmin ? Colors.indigo : Colors.amber.shade800,
                              size: 20,
                            ),
                          ),
                          title: Text(s['nombre'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('ID: ${s['dni']} • ${s['rol']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                        ),
                      );
                    },
                  ),
                ),
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
