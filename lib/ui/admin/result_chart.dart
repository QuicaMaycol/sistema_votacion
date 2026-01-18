import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/eleccion_pregunta.dart';

class ResultChart extends StatelessWidget {
  final Pregunta pregunta;
  final List<Map<String, dynamic>> resultados;
  final List<dynamic> opciones; // Opciones de la pregunta si es múltiple

  const ResultChart({
    super.key,
    required this.pregunta,
    required this.resultados,
    this.opciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            pregunta.textoPregunta,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20, right: 20, left: 10),
          child: SizedBox(
            height: 200,
            child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxValue() + 2,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= _getLabels().length) return const Text('');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_getLabels()[index], style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: _getBarGroups(),
            ),
          ),
        ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  double _getMaxValue() {
    if (resultados.isEmpty) return 5;
    double max = 0;
    for (var r in resultados) {
      if (r['total_votos'].toDouble() > max) max = r['total_votos'].toDouble();
    }
    return max;
  }

  List<String> _getLabels() {
    if (pregunta.tipo.name == 'OPCION_MULTIPLE') {
      return opciones.map((o) => o['texto_opcion'].toString()).toList();
    } else {
      // Para numéricos, mostramos los valores únicos votados
      final labels = resultados
          .map((r) => r['valor_numerico'].toString())
          .toSet()
          .toList();
      labels.sort();
      return labels;
    }
  }

  List<BarChartGroupData> _getBarGroups() {
    final labels = _getLabels();
    return List.generate(labels.length, (i) {
      final label = labels[i];
      double count = 0;

      if (pregunta.tipo.name == 'OPCION_MULTIPLE') {
         // Buscar por ID de opción correspondiente al label
         final opcionObj = opciones.firstWhere((o) => o['texto_opcion'] == label, orElse: () => null);
         if (opcionObj != null) {
           final r = resultados.firstWhere(
             (res) => res['opcion_elegida_id'] == opcionObj['id'], 
             orElse: () => {'total_votos': 0}
           );
           count = r['total_votos'].toDouble();
         }
      } else {
        final r = resultados.firstWhere(
          (res) => res['valor_numerico'].toString() == label,
          orElse: () => {'total_votos': 0}
        );
        count = r['total_votos'].toDouble();
      }

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count,
            color: Colors.blue.shade400,
            width: 25,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });
  }
}
