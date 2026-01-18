import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SocioDashboard extends StatelessWidget {
  const SocioDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del Votante'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: const Center(
        child: Text('Próximamente: Lista de votaciones disponibles.'),
      ),
    );
  }
}
