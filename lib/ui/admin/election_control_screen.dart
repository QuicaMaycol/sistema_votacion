import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';
import '../../models/eleccion_pregunta.dart';
import '../../models/enums.dart';
import '../../models/opcion_voto.dart';
import '../../services/election_service.dart';
import 'result_chart.dart';

class ElectionControlScreen extends StatefulWidget {
  final Eleccion eleccion;

  const ElectionControlScreen({super.key, required this.eleccion});

  @override
  State<ElectionControlScreen> createState() => _ElectionControlScreenState();
}

class _ElectionControlScreenState extends State<ElectionControlScreen> {
  final _electionService = ElectionService();
  late EstadoEleccion _estadoActual;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.eleccion.estado;
  }

  Future<void> _changeStatus(EstadoEleccion nuevoEstado) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cambio'),
        content: Text('¿Desea cambiar el estado de la elección a ${nuevoEstado.name.toUpperCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await _electionService.updateElectionStatus(widget.eleccion.id, nuevoEstado);
      setState(() => _estadoActual = nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Elección actualizada a ${nuevoEstado.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _confirmDeleteQuestion(String preguntaId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Pregunta'),
        content: const Text(
          '¿Estás seguro de eliminar esta pregunta?\n\n'
          '⚠️ Se eliminarán también todas las opciones y candidatos asociados.\n'
          'Esta acción no se puede deshacer.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _electionService.deleteQuestion(preguntaId);
        setState(() {}); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pregunta eliminada')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFD),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            widget.eleccion.titulo,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: isMobile ? 'Control' : 'Panel de Control'),
              Tab(text: isMobile ? 'Votos' : 'Resultados en Vivo'),
              Tab(text: isMobile ? 'Usuarios' : 'Participación'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildControlTab(isMobile),
            _buildResultsTab(),
            _buildParticipationTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlTab(bool isMobile) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 40),
              const Text(
                'Estructura de la Elección', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)
              ),
              const SizedBox(height: 16),
              _buildQuestionsList(),
              const SizedBox(height: 48),
              const Text(
                'Acciones de Gestión', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)
              ),
              const SizedBox(height: 20),
              _buildControlButtons(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsList() {
    return FutureBuilder<List<PreguntaCompleta>>(
      future: _electionService.getQuestionsByElection(widget.eleccion.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final preguntas = snapshot.data ?? [];
        if (preguntas.isEmpty) return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Esta elección no tiene preguntas cargadas.', style: TextStyle(color: Colors.grey)),
        );

        return Column(
          children: preguntas.map((pc) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: Center(child: Text((pc.pregunta.orden + 1).toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(pc.pregunta.textoPregunta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                      onPressed: () => _confirmDeleteQuestion(pc.pregunta.id),
                      tooltip: 'Eliminar Pregunta',
                    )
                  ],
                ),
                subtitle: Text('Tipo: ${pc.pregunta.tipo.name}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Column(
                      children: [
                        if (pc.pregunta.tipo == TipoPregunta.OPCION_MULTIPLE)
                          ...pc.opciones.map((o) => Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(Icons.radio_button_unchecked, size: 16, color: Colors.blueAccent),
                              title: Text(o.textoOpcion, style: const TextStyle(fontSize: 13)),
                            ),
                          ))
                        else if (pc.pregunta.tipo == TipoPregunta.INPUT_NUMERICO)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: const Row(
                              children: [
                                Icon(Icons.numbers, size: 16, color: Colors.blueAccent),
                                SizedBox(width: 12),
                                Text('Entrada numérica requerida', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          )
                        else if (pc.pregunta.tipo == TipoPregunta.CANDIDATOS)
                          ...pc.opciones.map((o) => Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.person, size: 14, color: Colors.white),
                              ),
                              title: Text(o.textoOpcion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ))
                      ],
                    ),
                  )
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DETALLES GENERALES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.2)),
                _statusBadge(_estadoActual),
              ],
            ),
            const SizedBox(height: 20),
            Text(widget.eleccion.titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(widget.eleccion.descripcion ?? 'Sin descripción', style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
            const Divider(height: 48, color: Color(0xFFF5F5F7)),
            Row(
              children: [
                Expanded(child: _infoItem(Icons.calendar_today_rounded, 'Inicio', widget.eleccion.fechaInicio.toString().split('.')[0])),
                Expanded(child: _infoItem(Icons.calendar_today_outlined, 'Fin', widget.eleccion.fechaFin.toString().split('.')[0])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(EstadoEleccion estado) {
    Color color = _getStatusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(estado.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    if (_isUpdating) return const Center(child: CircularProgressIndicator());

    if (_estadoActual == EstadoEleccion.BORRADOR) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)),
        child: Column(
          children: [
            const Text('Esta elección está en modo borrador. Los socios no pueden verla ni votar aún.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.green)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _changeStatus(EstadoEleccion.ACTIVA),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ACTIVAR ELECCIÓN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: Colors.green.shade200),
              ),
              onPressed: _showAddQuestionDialog,
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              label: const Text('AÑADIR PREGUNTA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
            ),
          ],
        ),
      );
    }

    if (_estadoActual == EstadoEleccion.ACTIVA) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100)),
        child: Column(
          children: [
            const Text('La elección está en curso. Al finalizarla, se cerrará el acceso a votación permanently.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.orange)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _changeStatus(EstadoEleccion.FINALIZADA),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('FINALIZAR ELECCIÓN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.grey.shade400, size: 40),
          const SizedBox(height: 16),
          const Text('ELECCIÓN FINALIZADA', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 16, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Ya no se aceptan más votos para esta elección.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
             onPressed: () => _changeStatus(EstadoEleccion.BORRADOR),
             icon: const Icon(Icons.edit_rounded, size: 16),
             label: const Text('REVERTIR A BORRADOR'),
             style: OutlinedButton.styleFrom(
               foregroundColor: Colors.grey.shade700,
               side: BorderSide(color: Colors.grey.shade400),
             ),
          ),
          const Text('Úselo para corregir errores. Si ya hubo votación, esto podría causar inconsistencias.', style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showAddQuestionDialog() {
    final preguntaController = TextEditingController();
    TipoPregunta selectedTipo = TipoPregunta.OPCION_MULTIPLE;
    List<String> opciones = [];
    final opcionesKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Añadir Pregunta'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                     controller: preguntaController,
                     decoration: const InputDecoration(labelText: 'Texto de la Pregunta'),
                   ),
                   const SizedBox(height: 16),
                   DropdownButtonFormField<TipoPregunta>(
                     value: selectedTipo,
                     decoration: const InputDecoration(labelText: 'Tipo de Respuesta'),
                     items: TipoPregunta.values.map((t) => DropdownMenuItem(
                       value: t,
                       child: Text(t.toShortString()),
                     )).toList(),
                     onChanged: (val) => setDialogState(() {
                       selectedTipo = val!;
                       if (val != TipoPregunta.OPCION_MULTIPLE) opciones.clear();
                       // Limpiar candidatos si cambia tipo? No necesariamente, pero buena práctica
                     }),
                   ),
                   
                   // --- LOGICA OPCION MULTIPLE ---
                   if (selectedTipo == TipoPregunta.OPCION_MULTIPLE) ...[
                     const SizedBox(height: 16),
                     const Text('Opciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                     // ... (mismo código de opciones) ...
                     ...opciones.asMap().entries.map((e) => ListTile(
                       dense: true,
                       title: Text(e.value),
                       trailing: IconButton(
                         icon: const Icon(Icons.close, size: 16),
                         onPressed: () => setDialogState(() => opciones.removeAt(e.key)),
                       ),
                     )),
                     Row(
                       children: [
                         Expanded(
                           child: Form(
                             key: opcionesKey,
                             child: TextFormField(
                               decoration: const InputDecoration(hintText: 'Nueva opción...'),
                               onFieldSubmitted: (val) {
                                 if (val.isNotEmpty) {
                                   setDialogState(() => opciones.add(val));
                                 }
                               },
                             ),
                           ),
                         ),
                         IconButton(onPressed: () {}, icon: const Icon(Icons.add)) 
                       ],
                     ),
                     const Text('Presione Enter para agregar opción', style: TextStyle(fontSize: 10, color: Colors.grey)),
                   ],

                   // --- LOGICA CANDIDATOS (CSV) ---
                   if (selectedTipo == TipoPregunta.CANDIDATOS) ...[
                     const SizedBox(height: 20),
                     Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                       child: Column(
                         children: [
                           const Icon(Icons.upload_file, color: Colors.blue, size: 30),
                           const SizedBox(height: 8),
                           const Text('Carga Masiva de Candidatos (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                           const SizedBox(height: 8),
                           Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                             child: const Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text('Formato requerido:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                 Text('• Debe incluir encabezados en la primera fila.', style: TextStyle(fontSize: 12)),
                                 Text('• Orden de columnas (BD):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                 Text('1. Nombre Completo', style: TextStyle(fontSize: 12)),
                                 Text('2. DNI', style: TextStyle(fontSize: 12)),
                                 Text('3. Sede', style: TextStyle(fontSize: 12)),
                                 Text('4. Postulacion', style: TextStyle(fontSize: 12)),
                                 Text('5. Numero Candidatura', style: TextStyle(fontSize: 12)),
                               ],
                             ),
                           ),
                           const SizedBox(height: 12),
                           const Text('Por favor respete el orden de columnas de la base de datos.', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                           const SizedBox(height: 12),
                           ElevatedButton.icon(
                             onPressed: () async {
                               try {
                                 FilePickerResult? result = await FilePicker.platform.pickFiles(
                                   type: FileType.custom,
                                   allowedExtensions: ['csv', 'txt'],
                                   withData: true, // Importante para web/desktop si no hay path directo
                                 );

                                 if (result != null) {
                                    final fileBytes = result.files.first.bytes;
                                    final fileContent = utf8.decode(fileBytes!);
                                    
                                    // Detección inteligente de delimitador
                                    String delimiter = ',';
                                    if (fileContent.contains(';') && !fileContent.split('\n')[0].contains(',')) {
                                      delimiter = ';';
                                    }

                                    final List<List<dynamic>> csvTable = CsvToListConverter(fieldDelimiter: delimiter).convert(fileContent, eol: '\n');
                                    
                                    // Procesar (asumiendo cabecera en fila 0)
                                    // Formato esperado: Nombre, DNI, Sede, Postulacion, Numero
                                    List<Map<String, dynamic>> parsed = [];
                                    for (var i = 1; i < csvTable.length; i++) {
                                      final row = csvTable[i];
                                      if (row.isEmpty || row[0].toString().isEmpty) continue;
                                      
                                      parsed.add({
                                        'nombre': row[0].toString(),
                                        'dni': row.length > 1 ? row[1].toString() : '',
                                        'sede': row.length > 2 ? row[2].toString() : '',
                                        'postulacion': row.length > 3 ? row[3].toString() : '',
                                        'numero': row.length > 4 ? row[4].toString() : '0',
                                      });
                                    }
                                    
                                    // Guardamos temporalmente en 'opciones' para reusar variable o mejor una nueva
                                    // Hack: Usamos 'opciones' para mostrar "Candidates loaded: X"
                                    setDialogState(() {
                                      // Limpiamos opciones textuales y ponemos un indicador
                                      opciones.clear(); 
                                      opciones.add('CSV_DATA:${jsonEncode(parsed)}');
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se cargaron ${parsed.length} candidatos (Delimitador: "$delimiter")')));
                                 }
                               } catch (e) {
                                 debugPrint('Error picking file: $e');
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error leyendo archivo')));
                               }
                             },
                             icon: const Icon(Icons.folder_open),
                             label: const Text('Seleccionar CSV'),
                             style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                           ),
                           if (opciones.isNotEmpty && opciones.first.startsWith('CSV_DATA:'))
                             Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Text(
                                 '✔ ${jsonDecode(opciones.first.substring(9)).length} candidatos listos para importar',
                                 style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                               ),
                             )
                         ],
                       ),
                     )
                   ]
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (preguntaController.text.isEmpty) return;
                
                // Validación para opción múltiple
                if (selectedTipo == TipoPregunta.OPCION_MULTIPLE && opciones.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Añada al menos una opción')));
                  return;
                }
                
                // Validación para candidatos
                if (selectedTipo == TipoPregunta.CANDIDATOS && (opciones.isEmpty || !opciones.first.startsWith('CSV_DATA:'))) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe cargar un archivo de candidatos')));
                   return;
                }

                try {
                  if (selectedTipo == TipoPregunta.CANDIDATOS) {
                    // Lógica especial para Candidatos
                    final rawJson = opciones.first.substring(9); // Remover 'CSV_DATA:'
                    final List<dynamic> rawList = jsonDecode(rawJson);
                    final List<Map<String, dynamic>> candidatosData = rawList.map((e) => e as Map<String, dynamic>).toList();

                    await _electionService.addQuestionWithCandidates(
                      eleccionId: widget.eleccion.id,
                      textoPregunta: preguntaController.text,
                      orden: 99,
                      candidatosData: candidatosData,
                    );
                  } else {
                    // Lógica normal
                    final newPregunta = PreguntaCompleta(
                      pregunta: Pregunta(
                        id: '', 
                        eleccionId: widget.eleccion.id,
                        textoPregunta: preguntaController.text, 
                        tipo: selectedTipo,
                        orden: 99
                      ),
                      opciones: opciones.map((t) => Opcion(
                        id: '', 
                        preguntaId: '', 
                        textoOpcion: t
                      )).toList().cast<Opcion>()
                    );

                    await _electionService.addQuestionToElection(
                      eleccionId: widget.eleccion.id,
                      pc: newPregunta,
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {}); // Refresh list
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pregunta añadida correctamente')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }, 
              child: const Text('Guardar Pregunta')
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(EstadoEleccion estado) {
    switch (estado) {
      case EstadoEleccion.BORRADOR: return Colors.blue;
      case EstadoEleccion.ACTIVA: return Colors.green;
      case EstadoEleccion.FINALIZADA: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildResultsTab() {
    return FutureBuilder(
      future: Future.wait([
        _electionService.getQuestionsByElection(widget.eleccion.id),
        _electionService.getResultsByElection(widget.eleccion.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final List<PreguntaCompleta> preguntas = (snapshot.data![0] as List).cast<PreguntaCompleta>();
        final List<Map<String, dynamic>> resultados = (snapshot.data![1] as List).cast<Map<String, dynamic>>();

        if (resultados.isEmpty) return const Center(child: Text('Aún no hay votos registrados.'));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: preguntas.length,
          itemBuilder: (context, index) {
            final pc = preguntas[index];
            final resultadosDePregunta = resultados.where((r) => r['pregunta_id'] == pc.pregunta.id).toList();
            
            final opcionesMap = pc.opciones.map((o) => {
              'id': o.id,
              'texto_opcion': o.textoOpcion
            }).toList();

            return ResultChart(
              pregunta: pc.pregunta,
              resultados: resultadosDePregunta,
              opciones: opcionesMap,
            );
          },
        );
      },
    );
  }

  Widget _buildParticipationTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _electionService.getParticipationReport(widget.eleccion.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final rawData = snapshot.data ?? [];

        // Deduplicar: cada socio debe aparecer una sola vez
        final Map<String, Map<String, dynamic>> uniqueUsers = {};
        for (var row in rawData) {
          final userId = row['usuario_id'] ?? row['nombre_usuario'];
          if (!uniqueUsers.containsKey(userId)) {
            uniqueUsers[userId] = Map<String, dynamic>.from(row);
          } else {
            // Si ya existe y el actual dice que ha votado, actualizamos (por seguridad)
            if (row['ha_votado'] == true) {
              uniqueUsers[userId]!['ha_votado'] = true;
              uniqueUsers[userId]!['fecha_voto'] = row['fecha_voto'];
            }
          }
        }

        final data = uniqueUsers.values.toList();
        int votaron = data.where((u) => u['ha_votado'] == true).length;
        int faltan = data.length - votaron;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCard('SOCIOS PARTICIPARON', votaron.toString(), Colors.green),
                  _statCard('SOCIOS PENDIENTES', faltan.toString(), Colors.orange),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final u = data[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u['ha_votado'] ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Icon(
                        u['ha_votado'] ? Icons.check : Icons.person_outline,
                        color: u['ha_votado'] ? Colors.green : Colors.grey,
                      ),
                    ),
                    title: Text(u['nombre_usuario']),
                    subtitle: Text(u['ha_votado'] 
                      ? 'Participó el ${u['fecha_voto'].toString().split('T')[0]}' 
                      : 'Aún no ha participado'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}
