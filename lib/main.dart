import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'models/enums.dart';
import 'ui/auth/login_screen.dart';
import 'ui/admin/admin_dashboard.dart';
import 'ui/socio/socio_dashboard.dart';
import 'ui/views/pending_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Votaciones',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = authProvider.currentProfile;

    if (profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text('Error al cargar el perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  authProvider.lastError ?? 'No se encontró la información del usuario en el sistema.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => authProvider.logout(),
                  child: const Text('Cerrar Sesión / Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (profile.estadoAcceso == EstadoUsuario.PENDIENTE) {
      return const PendingScreen();
    }

    if (profile.rol == RolUsuario.ADMIN) {
      return const AdminDashboard();
    }

    return SocioDashboard();
  }
}
