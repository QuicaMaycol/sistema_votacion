import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'models/enums.dart';
import 'ui/auth/login_screen.dart';
import 'reporte/reporte_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyAppReporte(),
    ),
  );
}

class MyAppReporte extends StatelessWidget {
  const MyAppReporte({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reportes de Votación',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ReporteWrapper(),
    );
  }
}

class ReporteWrapper extends StatelessWidget {
  const ReporteWrapper({super.key});

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
      return const Scaffold(
        body: Center(child: Text('Cargando perfil de administrador...')),
      );
    }

    // Solo permitir el acceso al reporte si es ADMIN o GERENCIA
    if (profile.rol == RolUsuario.ADMIN || profile.rol == RolUsuario.GERENCIA) {
      return const ReporteScreen();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Acceso Restringido',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text('Esta versión del sistema solo permite ver reportes.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => authProvider.logout(),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
