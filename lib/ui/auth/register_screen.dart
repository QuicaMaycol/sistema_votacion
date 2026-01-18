import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

enum TipoRegistro { socio, empresa }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  TipoRegistro _tipo = TipoRegistro.socio;

  // Controllers Comunes
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();

  // Controllers Empresa
  final _rucController = TextEditingController();
  final _nombreEmpresaController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _empresaEncontrada;

  Future<void> _validarRuc() async {
    if (_rucController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final empresa = await _authService.buscarEmpresaPorRuc(_rucController.text);
      setState(() {
        _empresaEncontrada = empresa;
        if (empresa == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RUC no encontrado. Contacte a su empresa.')),
          );
        }
      });
    } catch (e) {
      debugPrint('Error buscando RUC: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String msg = '';
      if (_tipo == TipoRegistro.socio) {
        if (_empresaEncontrada == null) throw 'Debe validar el RUC de su empresa primero';
        
        msg = await _authService.registerSocio(
          email: _emailController.text,
          password: _passwordController.text,
          nombre: _nombreController.text,
          dni: _dniController.text,
          empresaId: _empresaEncontrada!['id'],
        );
      } else {
        msg = await _authService.registerEmpresa(
          nombreEmpresa: _nombreEmpresaController.text,
          ruc: _rucController.text,
          adminEmail: _emailController.text,
          adminPassword: _passwordController.text,
          adminNombre: _nombreController.text,
          adminCelular: _dniController.text, // Usamos el mismo controller pero para celular
        );
      }

      if (mounted) {
        _mostrarDialogoExito(msg);
      }
    } catch (e) {
      debugPrint('DEBUG: Error en registro: $e');
      if (mounted) {
        String errorMsg = e.toString();
        bool isNotConfirmed = false;

        // 1. Verificación por tipo (más robusta)
        if (e is AuthException) {
          if (e.code == 'email_not_confirmed' || e.message.toLowerCase().contains('not confirmed')) {
            isNotConfirmed = true;
          }
        } 
        
        // 2. Verificación por String (seguridad extra)
        if (errorMsg.toLowerCase().contains('email_not_confirmed') || 
            errorMsg.toLowerCase().contains('not confirmed')) {
          isNotConfirmed = true;
        }

        if (isNotConfirmed) {
          ScaffoldMessenger.of(context).clearSnackBars();
          _mostrarDialogoExito('¡Casi listo! Tu correo ya está registrado pero falta confirmarlo. Por favor, busca el enlace en tu entrada o SPAM para activar tu cuenta.');
          return;
        }

        // Limpieza de mensajes técnicos para el usuario
        if (errorMsg.contains('Failed to fetch') || errorMsg.contains('ClientException')) {
          errorMsg = 'Revise su conexión a internet.';
        } else if (errorMsg.contains('PostgrestException')) {
          if (errorMsg.contains('row-level security policy')) {
            errorMsg = 'Error de permisos. Contacte al administrador.';
          } else {
            final regExp = RegExp(r'message: (.*?)(?:\n|$)');
            final match = regExp.firstMatch(errorMsg);
            if (match != null) errorMsg = match.group(1) ?? errorMsg;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DETALLE: $errorMsg'),
            backgroundColor: Colors.red.shade800,
          )
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoExito(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Colors.blue, size: 60),
            SizedBox(height: 16),
            Text('¡Verifica tu correo!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Importante: Revisa la carpeta de SPAM o Correo no deseado.',
                      style: TextStyle(fontSize: 13, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Si ya tienes cuenta en otro de nuestros sistemas, intenta iniciar sesión directamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context); // Cierra diálogo
                Navigator.pop(context); // Regresa al Login
              },
              child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SegmentedButton<TipoRegistro>(
                    segments: const [
                      ButtonSegment(value: TipoRegistro.socio, label: Text('Soy Socio'), icon: Icon(Icons.person)),
                      ButtonSegment(value: TipoRegistro.empresa, label: Text('Soy Empresa'), icon: Icon(Icons.business)),
                    ],
                    selected: {_tipo},
                    onSelectionChanged: (v) => setState(() {
                      _tipo = v.first;
                      _empresaEncontrada = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                  
                  // Campo RUC (Búsqueda para socio, ingreso para empresa)
                  // Campo RUC para búsqueda (Socio) o ingreso (Empresa)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rucController,
                          decoration: InputDecoration(
                            labelText: 'RUC de la Empresa',
                            border: const OutlineInputBorder(),
                            helperText: _tipo == TipoRegistro.socio 
                                ? 'Ingrese el RUC para buscar su empresa' 
                                : 'Ingrese el RUC legal de su empresa',
                          ),
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          onChanged: (v) {
                            if (_tipo == TipoRegistro.socio) {
                              setState(() => _empresaEncontrada = null);
                            }
                          },
                        ),
                      ),
                      if (_tipo == TipoRegistro.socio) ...[
                         const SizedBox(width: 8),
                         IconButton.filled(
                          onPressed: _isLoading ? null : _validarRuc,
                          icon: const Icon(Icons.search),
                          tooltip: 'Validar RUC',
                        )
                      ],
                    ],
                  ),

                  if (_tipo == TipoRegistro.socio && _empresaEncontrada != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.business, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Empresa encontrada: ${_empresaEncontrada!['nombre']}', 
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_tipo == TipoRegistro.empresa) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreEmpresaController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Empresa',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ],

                  const Divider(height: 40),
                  const Text('Datos Personales / Administrador', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre Completo'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dniController,
                    decoration: InputDecoration(
                      labelText: _tipo == TipoRegistro.socio ? 'DNI' : 'Número de Celular',
                      hintText: _tipo == TipoRegistro.socio ? '8 dígitos' : '9 dígitos',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return 'Requerido';
                      if (_tipo == TipoRegistro.socio && v.length != 8) return 'DNI debe tener 8 dígitos';
                      if (_tipo == TipoRegistro.empresa && v.length < 9) return 'Celular no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email de acceso'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),

                  const SizedBox(height: 32),
                  _isLoading 
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        onPressed: _submit,
                        child: Text(_tipo == TipoRegistro.socio ? 'Solicitar Acceso' : 'Registrar Empresa'),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
