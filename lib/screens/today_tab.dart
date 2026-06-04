import 'package:flutter/material.dart';
import '../models/reading_model.dart';
import 'widgets/streak_badge.dart';

class TodayTab extends StatelessWidget {
  final DevotionalReading todayReading;
  final Function(DevotionalReading) onToggle;
  final int streakCount;

  const TodayTab({
    super.key,
    required this.todayReading,
    required this.onToggle,
    required this.streakCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEvent = todayReading.specialEvent != null && todayReading.specialEvent!.isNotEmpty;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // Muestra la racha actual del hermano
              StreakBadge(streakCount: streakCount),
              const SizedBox(height: 16),

              // Tarjeta principal del capítulo del día
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        "CAPÍTULO DEL DÍA",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        todayReading.bookAndChapter,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      if (hasEvent) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            todayReading.specialEvent!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // BOTÓN CORREGIDO: Llama a la función del HomeScreen que sí guarda en Supabase
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: todayReading.isCompleted ? Colors.grey.shade200 : theme.primaryColor,
                            foregroundColor: todayReading.isCompleted ? Colors.grey.shade700 : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(todayReading.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked),
                          label: Text(
                            todayReading.isCompleted ? "Lectura Completada" : "Marcar como leído",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          onPressed: () => onToggle(todayReading), // 👈 Aquí usamos la función conectada a Supabase
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sección del versículo de la semana
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Versículo de la Semana",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        todayReading.dailyVerse ?? '"Te he puesto para luz de los gentiles, a fin de que seas para salvación hasta lo último de la tierra."',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        todayReading.dailyVerseRef ?? "Hechos 13:47",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}