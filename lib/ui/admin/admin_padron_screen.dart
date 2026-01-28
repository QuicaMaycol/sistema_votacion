import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/enums.dart';

class AdminPadronScreen extends StatefulWidget {
  final String empresaId;
  const AdminPadronScreen({super.key, required this.empresaId});

  @override
  State<AdminPadronScreen> createState() => _AdminPadronScreenState();
}

class _AdminPadronScreenState extends State<AdminPadronScreen> {
  bool _isLoading = false;
  String _statusMessage = 'Selecciona un archivo CSV para importar.';
  List<List<dynamic>> _data = [];
  int _successCount = 0;
  int _errorCount = 0;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'Procesando archivo...';
        });

        // Leer contenido
        String csvString;
        if (kIsWeb) {
           final bytes = result.files.first.bytes;
           csvString = utf8.decode(bytes!);
        } else {
           final file = File(result.files.single.path!);
           csvString = await file.readAsString();
        }

        // Parsear CSV
        List<List<dynamic>> rows = const CsvToListConverter(
          fieldDelimiter: ',', // Intenta coma
          eol: '\n',
          shouldParseNumbers: false, // Queremos DNI como string
        ).convert(csvString);

        if (rows.isEmpty || (rows.isNotEmpty && rows[0].length < 2)) {
          // Intenta punto y coma si falló
           rows = const CsvToListConverter(
            fieldDelimiter: ';',
            eol: '\n',
             shouldParseNumbers: false,
          ).convert(csvString);
        }

        setState(() {
          _data = rows;
          _statusMessage = 'Archivo cargado. ${_data.length} registros detectados.\nPresiona "Importar" para subir.';
          _isLoading = false;
        });

      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al leer archivo: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _processUpload() async {
    if (_data.isEmpty) return;

    setState(() {
      _isLoading = true;
      _successCount = 0;
      _errorCount = 0;
      _statusMessage = 'Iniciando importación masiva...';
    });

    final client = Supabase.instance.client;
    final uuid = Uuid();

    // Procesar en lotes de 50 para no ahogar la red
    int batchSize = 50;
    for (var i = 0; i < _data.length; i += batchSize) {
      final end = (i + batchSize < _data.length) ? i + batchSize : _data.length;
      final batch = _data.sublist(i, end);
      
      List<Map<String, dynamic>> upsertList = [];

      for (var row in batch) {
        if (row.isEmpty) continue;
        // Asumimos formato: DNI, NOMBRE (sin cabecera o saltando si detectamos texto)
        String rawDni = row[0].toString().trim();
        if (rawDni.toLowerCase() == 'dni' || rawDni.isEmpty) continue; // Skip header

        String nombre = (row.length > 1) ? row[1].toString().trim() : 'Socio $rawDni';
        
        // Determinar ID: idealmente determinístico o nuevo
        // Si usamos DNI como semilla o simplemente generamos uno nuevo.
        // PERO: Si el usuario ya existe, queremos actualizarlo, no duplicarlo.
        // Si la PK es UUID, necesitamos saber su UUID para actualizarlo.
        // ESTRATEGIA: Buscar por DNI primero es lento uno por uno.
        // ESTRATEGIA MEJOR: Hacer upsert usando DNI como clave? No, DNI no es PK.
        // ESTRATEGIA ACTUAL: Consultar si existe DNI.
        // Para simplificar: Generamos un UUID nuevo para todos. SI existe DNI se duplicará?
        // Deberías tener una constraint UNIQUE(dni, empresa_id) en la BD.
        
        final newId = uuid.v4();
        
        upsertList.add({
          'id': newId, // Esto podría fallar si el DNI ya existe y tiene constraint unique. 
                       // Supabase upsert por default usa PK.
                       // Si queremos upsert por DNI, necesitamos saber el ID existente.
          'empresa_id': widget.empresaId,
          'dni': rawDni,
          'nombre': nombre,
          'rol': 'SOCIO',
          'estado_acceso': 'ACTIVO',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Si no tenemos constraint unique en DNI, esto insertará duplicados con IDs nuevos.
      // Solución Robustez: Usar upsert onConflict columns.
      // Pero 'id' es PK.
      // Intentaremos insertar. Si falla por unique constraint (espero que tengas una en DNI), lo ignoramos.
      
      if (upsertList.isNotEmpty) {
          try {
            // Upsert on conflict DNI? 
            // supabase.from().upsert(..., onConflict: 'dni')
            // Esto requiere que dni tenga restricción unique.
            await client.schema('votaciones').from('perfiles').upsert(
              upsertList, 
              onConflict: 'dni, empresa_id', // Coincide con el constraint creado en fix_indices.sql
              ignoreDuplicates: false, // Queremos actualizar si existe
            );
            _successCount += upsertList.length;
          } catch (e) {
            debugPrint('Error en lote: $e');
            // Fallback: Intentar uno a uno si falla el lote
            _errorCount += upsertList.length;
          }
      }

      setState(() {
        _statusMessage = 'Procesando... Éxitos: $_successCount, Errores: $_errorCount';
      });
    }

     setState(() {
      _isLoading = false;
      _statusMessage = 'Proceso finalizado.\nImportados correctamente: $_successCount\nFallidos: $_errorCount';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carga Masiva de Padrón')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instrucciones:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text('1. Prepara un archivo CSV con columnas: DNI, NOMBRE'),
            const Text('2. No incluyas cabeceras (o serán ignoradas si dicen "DNI")'),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Seleccionar Archivo CSV'),
                ),
                const SizedBox(width: 16),
                if (_data.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: _isLoading ? null : _processUpload,
                    icon: const Icon(Icons.save),
                    label: const Text('Importar a Base de Datos'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _errorCount > 0 ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            const Divider(height: 32),
            if (_data.isNotEmpty) ...[
              const Text('Vista Previa (Primeros 5 registros):', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _data.take(5).length,
                  itemBuilder: (context, index) {
                    final row = _data[index];
                    return ListTile(
                      dense: true,
                      leading: Text('${index + 1}'),
                      title: Text(row.length > 1 ? row[1].toString() : 'Sin Nombre'),
                      subtitle: Text(row.isNotEmpty ? row[0].toString() : 'Sin DNI'),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
