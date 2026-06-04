import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyProgressChart extends StatelessWidget {
  final List<bool> weeklyProgress; // Recibe una lista de 7 booleanos reales del progreso del usuario

  const WeeklyProgressChart({super.key, required this.weeklyProgress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Si por algún motivo viene vacía, inicializamos los 7 días en falso (sin progreso)
    final progress = weeklyProgress.length == 7 ? weeklyProgress : List.generate(7, (_) => false);

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1, 
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[value.toInt()], 
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (index) {
            // Si el booleano del día es verdadero se pinta verde, si es falso se queda gris
            final isDone = progress[index];
            return _makeBarGroup(
              index, 
              isDone ? 1.0 : 0.05, // Una línea mínima si está vacío para mantener estética
              isDone ? theme.primaryColor : Colors.grey.withValues(alpha: 0.2)
            );
          }),
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 14,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}